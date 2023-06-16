import CoreLocation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Foundation
import OSLog
import RealmSwift

//
//          applyLocally                         upsertCmd                       decode
// Realm  <--------------                      <-----------                    <--------
//                         UpsertGeometryCommand                FirestoreGeometry           Firestore

/// This object provides the way to sync Firestore backend data with local Realm db.
class ProjectModelFirestoreSync {
    /// The model to synchronize Firestore with
    private unowned let model: ProjectModel

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

        // after this point it's only registering for observation and the function returns
        listeners.append(contentsOf: [
            model.sync(collection(.canvas), as: FirestoreCanvas.self),
            model.sync(collection(.canvasSource), as: FirestoreCanvasSource.self),
            model.sync(collection(.statusName), as: FirestoreStatusName.self),
            model.sync(collection(.tagName), as: FirestoreTagName.self),
            model.sync(collection(.participant), as: FirestoreParticipant.self),
            model.sync(collection(.geometry), as: FirestoreGeometry.self),
            model.sync(collection(.feature), as: FirestoreFeature.self),
            model.sync(collection(.collaboration), as: FirestoreCollaboration.self),
            model.sync(collection(.comment), as: FirestoreComment.self),
            model.sync(collection(.update), as: FirestoreUpdate.self),
            model.sync(collection(.upload), as: FirestoreUpload.self),
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
            model.replaceDocuments(with: canvases.documents, as: FirestoreCanvas.self, inRealm: realm)
            model.replaceDocuments(with: canvasSources.documents, as: FirestoreCanvasSource.self, inRealm: realm)
            try user.upsert(withId: model.userId, inRealm: realm)
            model.replaceDocuments(with: statuses.documents, as: FirestoreStatusName.self, inRealm: realm)
        }
    }

    /// Deregisters all observers.
    /// Will be called on deinit
    func stop() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
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
            let data = [
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
