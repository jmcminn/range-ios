import CoreLocation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseFunctions
import FirebaseSharedSwift
import Foundation
import OSLog
import RealmSwift
import Sentry

//
//          applyLocally                         upsertCmd                       decode
// Realm  <--------------                      <-----------                    <--------
//                         UpsertGeometryCommand                FirestoreGeometry           Firestore

/// This object provides the way to sync Firestore backend data with local Realm db.
class ProjectModelFirestoreSync {
    /// The model to synchronize Firestore with
    private let model: ProjectModel

    /// Firestore reference
    let firestore: Firestore
    /// Access to Firestore project document
    lazy var projectRef = firestore.document("projects/\(model.projectId)")
    /// Access to project subcollections based on the document type
    func collection(_ docType: FirestoreDocumentType) -> CollectionReference {
        projectRef.collection(docType.rawValue)
    }

    var listeners: [ListenerRegistration] = []

    /// Initialize sync for given `ProjectModel`
    init(model: ProjectModel) {
        self.model = model
        firestore = Firestore.firestore()
    }

    deinit {
        stop()
    }

    /// Starts synchronization - observes all relevant paths and updates the db.
    func start() async {
        // wait for the initial sync of the required data
        do {
            try await doInitialSync()
        } catch {
            Logger.firestore.error("initial sync failed: \(error.localizedDescription)")
        }

        // get all collaborations data
        do {
            let timestamp = try await model.getAllData()
            observeFeed(since: timestamp)
        } catch {
            Logger.functions.error("getAllDataForProject failed: \(error.localizedDescription)")
        }
        
        // Get the remaining data.
        // Not required as initial data but we still need to fetch all to remove any data in local
        // db that was already removed on the server side. We cannot rely on the Firestore persistence
        // because it would only report the removed documents once. And we need it also if multiple
        // users are logging in/out on 1 device.
        // This is a fire-and-forget call, we don't want to block the start function waiting for all 
        // these docs
        Task {
            do {
                try await remainingDocumentsSync()
            } catch {
                Logger.functions.error("remainingDocumentsSync failed: \(error.localizedDescription)")
            }
        }

        // after this point it's only registering for observation and the function returns
        listeners.append(contentsOf: [
            model.sync(collection(.canvas), as: FirestoreCanvas.self),
            model.sync(collection(.canvasSource), as: FirestoreCanvasSource.self),
            model.sync(collection(.statusName), as: FirestoreStatusName.self),
            model.sync(collection(.tagName), as: FirestoreTagName.self),
            model.sync(collection(.participant), as: FirestoreParticipant.self),
            model.sync(collection(.suspendedParticipant), as: FirestoreSuspendedParticipant.self),
        ])
    }

    /// Do the initial sync by getting the documents for project summary, initial canvas and current user which are required for loading
    /// the project (see `ProjectModel.loadProject`)
    private func doInitialSync() async throws {
        // do this in parallel

        // one of the reasons we need to get the project summary and user is that it's also
        // synced by projects model, so just syncing it here would not have an effect if it's
        // already in the Firestore SDK cache and is not updated (as we ignore cached changes
        // when syncing from firestore using `model.sync`)
        async let projectSummaryRequest = projectRef.getDocument(as: FirestoreProjectSummary.self)
        async let canvasesRequest = collection(.canvas).getDocuments()
        async let canvasSourcesRequest = collection(.canvasSource).getDocuments()
        async let userRequest = collection(.participant).document(model.userId)
            .getDocument(as: FirestoreParticipant.self)

        // fetch statuses in initial sync so they're guaranteed to be fetched before other objects
        // this way they'll be placed in local db in the same order as stored in Firestore.
        // If not done here, we could be fetching some collaboration before fetching it's status
        // and creating some placeholder status objects in the local db that would be out of order
        // We need statuses to keep the ordering from db as currently the order is not modelled in any way.
        async let statusesRequest = collection(.statusName).getDocuments()

        // await for results
        let projectSummary = try await projectSummaryRequest
        let canvases = try await canvasesRequest
        let canvasSources = try await canvasSourcesRequest
        let user = try await userRequest
        let statuses = try await statusesRequest

        // store in the db
        try await model.write { [self] realm in
            try projectSummary.upsert(withId: model.projectId, inRealm: realm)
            model.upsertDocuments(canvases.documents, as: FirestoreCanvas.self, inRealm: realm, replacing: true)
            model.upsertDocuments(canvasSources.documents, as: FirestoreCanvasSource.self, inRealm: realm, replacing: true)
            try user.upsert(withId: model.userId, inRealm: realm)
            model.upsertDocuments(statuses.documents, as: FirestoreStatusName.self, inRealm: realm, replacing: true)
        }
    }
    
    /// Fetches documents that are not required to start the project model but we still need to fetch them once (in addition to observing
    /// the collection) in order to remove any documents in local db that were removed on the server side.
    private func remainingDocumentsSync() async throws {
        async let tagsRequest = collection(.tagName).getDocuments()
        async let participantsRequest = collection(.participant).getDocuments()
        async let suspendedParticipantsRequest = collection(.suspendedParticipant).getDocuments()

        let tags = try await tagsRequest
        let participants = try await participantsRequest
        let suspendedParticipants = try await suspendedParticipantsRequest

        // store in the db
        try await model.write { [self] realm in
            // This requires that each command is more specific which ids are created/updated/removed
            model.upsertDocuments(tags.documents, as: FirestoreTagName.self, inRealm: realm, replacing: true)
            // we cannot replace participants and suspendedParticipants separately, as they are modelled
            // as Participant in Realm (same type). They need to be replaced as a whole.
            // 1. upsert new/changed documents:
            model.upsertDocuments(participants.documents, as: FirestoreParticipant.self, inRealm: realm, replacing: false)
            model.upsertDocuments(suspendedParticipants.documents, as: FirestoreSuspendedParticipant.self, inRealm: realm, replacing: false)
            // 2. remove the ones not in any of the lists:
            let allParticipantIds = participants.documents.map(\.documentID) + suspendedParticipants.documents.map(\.documentID)
            model.removeObjectsNotMatchingIds(allParticipantIds, ofType: Participant.self, inRealm: realm)
        }
    }

    /// Deregisters all observers.
    /// Will be called on deinit
    func stop() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
}

// MARK: - feed sync

extension ProjectModelFirestoreSync {
    // Observe feed and apply changes to local db
    private func observeFeed(since timestamp: Date) {
        let feedItems = projectRef.collection("participants/\(model.userId)/feedItems")
        let feedItemsQuery = feedItems.whereField("createdAt", isGreaterThanOrEqualTo: timestamp)

        let feedItemsListener = feedItemsQuery.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            guard let snapshot else {
                Logger.firestore.error("\(feedItems.path) fetching snapshots failed: \(error!.localizedDescription)")
                return
            }

            self.model.writeQueue.async { [weak self] in
                guard let self else { return }
                do {
                    try self.model.writeRealm.write {
                        let feedItemsWithIds = snapshot.documentChanges.compactMap { documentChange in
                            self.getFeedItem(documentChange.document)
                        }
                        feedItemsWithIds.forEach { id, feedItem in
                            self.handleFeedItem(feedItem, id: id, inRealm: self.model.writeRealm)
                        }
                        // Update feedLastUpdatedTimestamp so next getAllData doesn't refetch what was already
                        // covered by feed updates
                        if let maxFeedItemTimestamp = feedItemsWithIds.map(\.1.createdAt).max() {
                            self.model.writeRealm.add(
                                ProjectMetadata(feedLastUpdatedTimestamp: maxFeedItemTimestamp),
                                update: .modified
                            )
                        }
                    }
                } catch {
                    Logger.model.error("Storing feed item changes failed: \(error.localizedDescription)")
                }
            }
        }
        listeners.append(feedItemsListener)
    }

    private func getFeedItem(_ doc: DocumentSnapshot) -> (String, FirestoreFeedItem)? {
        let decoder = Firestore.Decoder()
        do {
            return (doc.documentID, try doc.data(as: FirestoreFeedItem.self, decoder: decoder))
        } catch {
            Logger.firestore.error(
                "Feed item decoding failure: \(doc.reference.path): \(error.localizedDescription)"
            )
            return nil
        }
    }

    private func handleFeedItem(_ item: FirestoreFeedItem, id: String, inRealm realm: Realm) {
        switch item.itemType {
        case "Organization": handleOrganizationFeedItem(item, id: id, inRealm: realm)
        case "Collaboration": handleCollaborationFeedItem(item, id: id, inRealm: realm)
        case "Comment": handleCommentFeedItem(item, id: id, inRealm: realm)
        case "Update": handleUpdateFeedItem(item, id: id, inRealm: realm)
        case "Upload": handleUploadFeedItem(item, id: id, inRealm: realm)
        default: reportUnsupportedFeedItem(item, id: id)
        }
    }

    private func handleOrganizationFeedItem(_ item: FirestoreFeedItem, id: String, inRealm _: Realm) {
        switch item.action {
        case "role-changed":
            // role-changed is a big change that may have multiple changes (not reported separately
            // via feed items).
            // We could trigger getting all data (which will most probably do a full server-side-forced 
            // fetch, as it will ignore the since parameter because of this `role-changed` feed item
            // it'll also observe)
            // But instead it's handled in the ProjectFlowController by observing the user role
            // and going back to projects listing, so we don't have to do all the UI updates in place
//            runAsyncFeedBlock(id) {
//                _ = try await self.model.getAllData()
//            }
            break
        default:
            reportUnsupportedFeedItem(item, id: id)
        }
    }

    private func handleCollaborationFeedItem(_ item: FirestoreFeedItem, id: String, inRealm realm: Realm) {
        switch item.action {
        case "added", "updated":
            runAsyncFeedBlock(id) {
                let collaboration = try await self.collection(.collaboration).document(item.itemId)
                    .getDocument(as: FirestoreCollaboration.self)
                let geometry = try await self.collection(.geometry).document(collaboration.geometryId)
                    .getDocument(as: FirestoreGeometry.self)
                try await self.model.write { realm in
                    try geometry.upsert(withId: collaboration.geometryId, inRealm: realm)
                    try collaboration.upsert(withId: item.itemId, inRealm: realm)
                }
            }
        case "access-gained":
            runAsyncFeedBlock(id) {
                let collaboration = try await self.collection(.collaboration).document(item.itemId)
                    .getDocument(as: FirestoreCollaboration.self)
                let geometry = try await self.collection(.geometry).document(collaboration.geometryId)
                    .getDocument(as: FirestoreGeometry.self)
                let comments = try await self.collection(.comment).whereField("collaborationId", isEqualTo: item.itemId).getDocuments()
                let updates = try await self.collection(.update).whereField("collaborationId", isEqualTo: item.itemId).getDocuments()
                let uploads = try await self.collection(.upload).whereField("collaborationId", isEqualTo: item.itemId).getDocuments()
                try await self.model.write { realm in
                    try geometry.upsert(withId: collaboration.geometryId, inRealm: realm)
                    try collaboration.upsert(withId: item.itemId, inRealm: realm)
                    self.model.upsertDocuments(comments.documents, as: FirestoreComment.self, inRealm: realm)
                    self.model.upsertDocuments(updates.documents, as: FirestoreUpdate.self, inRealm: realm)
                    self.model.upsertDocuments(uploads.documents, as: FirestoreUpload.self, inRealm: realm)
                }
            }
        case "deleted", "access-lost":
            model.deleteLocalCollaborations([item.itemId], inRealm: realm)
        default:
            reportUnsupportedFeedItem(item, id: id)
        }
    }

    private func handleCommentFeedItem(_ item: FirestoreFeedItem, id: String, inRealm realm: Realm) {
        switch item.action {
        case "added", "updated":
            runAsyncFeedBlock(id) {
                let comment = try await self.collection(.comment).document(item.itemId)
                    .getDocument(as: FirestoreComment.self)
                try await self.model.write { realm in
                    try comment.upsert(withId: item.itemId, inRealm: realm)
                }
            }
        case "deleted":
            model.deleteLocalComments([item.itemId], inRealm: realm)
        default:
            reportUnsupportedFeedItem(item, id: id)
        }
    }

    private func handleUpdateFeedItem(_ item: FirestoreFeedItem, id: String, inRealm _: Realm) {
        switch item.action {
        case "added":
            runAsyncFeedBlock(id) {
                let update = try await self.collection(.update).document(item.itemId)
                    .getDocument(as: FirestoreUpdate.self)
                try await self.model.write { realm in
                    try update.upsert(withId: item.itemId, inRealm: realm)
                }
            }
        default:
            reportUnsupportedFeedItem(item, id: id)
        }
    }

    private func handleUploadFeedItem(_ item: FirestoreFeedItem, id: String, inRealm realm: Realm) {
        switch item.action {
        case "added", "updated":
            runAsyncFeedBlock(id) {
                let upload = try await self.collection(.upload).document(item.itemId)
                    .getDocument(as: FirestoreUpload.self)
                try await self.model.write { realm in
                    try upload.upsert(withId: item.itemId, inRealm: realm)
                }
            }
        case "deleted":
            model.deleteLocalUploads([item.itemId], inRealm: realm)
        default:
            reportUnsupportedFeedItem(item, id: id)
        }
    }

    // just a wrapper for async block and exception logger
    private func runAsyncFeedBlock(_ docId: String, _ block: @escaping () async throws -> Void) {
        Task {
            do {
                try await block()
            } catch {
                Logger.model.error("Failed to process feed item \(docId): \(error.localizedDescription)")
            }
        }
    }

    private func reportUnsupportedFeedItem(_ item: FirestoreFeedItem, id: String) {
        SentrySDK.capture(error: "Unsupported feed item") { scope in
            scope.setExtras([
                "projectId": self.model.projectId,
                "userId": self.model.userId,
                "id": id,
                "itemId": item.itemId,
                "itemType": item.itemType,
                "action": item.action,
            ])
            scope.setLevel(.warning)
        }
    }
}

// MARK: - presence reporting

extension ProjectModelFirestoreSync {
    /// This is the only function that stores data directly in the Firestore. All other updates are going through Pending Actions model but
    /// presence does not make sense in offline mode
    /// The presence is reported for current user and current canvas, the timestamp is server side.
    func reportPresence(coordinates: CLLocationCoordinate2D) {
        let canvasId = model.currentCanvas.id
        let documentRef = collection(.presence).document(model.userId)
        firestore.runTransaction { tx, _ in
            let data: [String: Any] = [
                "canvas": canvasId,
                "lastPresencePlace": [coordinates.longitude, coordinates.latitude],
                "lastPresenceTimestamp": FieldValue.serverTimestamp(),
            ]
            tx.setData(data, forDocument: documentRef)
            return true
        } completion: { _, error in
            if let error = error {
                Logger.firestore.debug("report presence transaction failed: \(error.localizedDescription)")
            }
        }
    }
}
