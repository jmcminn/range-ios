import CoreLocation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Foundation
import OSLog
import RealmSwift

/// Protocol to be adopted by firebase objects that can be stored in Realm
protocol FirestoreToRealmSyncable {
    /// The type used to store the objects in the model Realm db
    associatedtype ModelType: Object
    /// Upsert this element with given id to given Realm. Will be performed in a realm write transaction
    func upsert(withId id: String, inRealm realm: Realm) throws
}

//
//          applyLocally                         upsertCmd                       decode
// Realm  <--------------                      <-----------                    <--------
//                         UpsertGeometryCommand                FirebaseGeometry             Firestore

/// This object provides the way to sync Firestore backend data with local Realm db.
class ProjectModelFirestoreSync {
    /// The model to synchronize Firebase with
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
        syncDetails(collection(.canvas), as: FirebasePDFCanvas.self)
        syncDetails(collection(.statusName), as: FirebaseStatusName.self)
        syncDetails(collection(.tagName), as: FirebaseTagName.self)
        syncDetails(collection(.participant), as: FirebaseParticipant.self)
        syncDetails(collection(.geometry), as: FirebaseGeometry.self)
        syncDetails(collection(.feature), as: FirebaseFeature.self)
        syncDetails(collection(.collaboration), as: FirebaseCollaboration.self)
        syncDetails(collection(.comment), as: FirebaseComment.self)
        syncDetails(collection(.update), as: FirebaseUpdate.self)
        syncDetails(collection(.upload), as: FirebaseUpload.self)
    }

    /// Do the initial sync by getting the documents for project summary, initial canvas and current user which are required for loading
    /// the project (see `ProjectModel.loadProject`)
    private func doInitialSync() async throws {
        // do this in parallel
        async let projectSummaryRequest = projectRef.getDocument(as: FirebaseProjectSummary.self)
        async let canvasesRequest = collection(.canvas).getDocuments()
        async let userRequest = collection(.participant).document(model.userId)
            .getDocument(as: FirebaseParticipant.self)

        // await for results
        let projectSummary = try await projectSummaryRequest
        let canvases = try await canvasesRequest
        let user = try await userRequest

        // store in the db
        try await model.write { realm in
            try projectSummary.upsert(withId: self.model.projectId, inRealm: realm)
            try canvases.documents.forEach {
                let canvas = try $0.data(as: FirebasePDFCanvas.self)
                try canvas.upsert(withId: $0.documentID, inRealm: realm)
            }
            try user.upsert(withId: self.model.userId, inRealm: realm)
        }
    }

    /// Convenience function to register listeners for given reference and invoke FirestoreToRealmSyncable methods on decoded objects to update the Realm state.
    ///  - Parameters:
    ///     - collectionRef:  the collection to observe for .childAdded, .childChanged and .childRemoved
    ///     - type: the type to use for decoding the firebase SnapshotData for given db reference
    private func syncDetails<T: Decodable & FirestoreToRealmSyncable>(
        _ collectionRef: CollectionReference,
        as type: T.Type
    ) {
        /// Applies the changes from document to Realm
        let syncDocument: (Realm, DocumentChangeType, QueryDocumentSnapshot) throws
            -> Void = { realm, changeType, snapshot in
                let decoder = Firestore.Decoder()
                let firebaseObject = try snapshot.data(as: type, decoder: decoder)
                try realm.write {
                    if changeType == .added || changeType == .modified {
                        try firebaseObject.upsert(withId: snapshot.documentID, inRealm: realm)
                    } else if changeType == .removed {
                        guard let object = realm.object(ofType: type.ModelType, forPrimaryKey: snapshot.documentID)
                        else {
                            return
                        }
                        realm.delete(object)
                    } else {
                        throw "Change type \(changeType) not handled"
                    }
                }
            }
        let loggingKey = collectionRef.collectionID
        let listenerRegistration = collectionRef.addSnapshotListener { [weak self] querySnapshot, error in
            guard let self = self else { return }
            guard let snapshot = querySnapshot else {
                Logger.firestore.error("\(loggingKey) fetching snapshots failed: \(error!.localizedDescription)")
                return
            }
            guard !snapshot.metadata.isFromCache else {
                // we don't want data from cache. Firestore will report all local objects when the app
                // is starting even in offline mode (because it has persistence enabled, see AppDelegate
                // Firestore config comment for why it has to be enabled).
                // This data from cache is not needed, because we have it in Realm and would override
                // any local pending changes. So it would flicker but for a potentially very long time:
                // From the time user restarted the app in offline after making local changes until the user is back online.
                return
            }
            self.model.writeQueue.async {
                snapshot.documentChanges.forEach { diff in
                    let document = diff.document
                    Logger.firestore.debug("\(loggingKey) \(diff.type) \(document.documentID, privacy: .public)")
                    do {
                        try syncDocument(self.model.writeRealm, diff.type, document)
                    } catch let DecodingError.dataCorrupted(context),
                                let DecodingError.keyNotFound(_, context),
                                let DecodingError.valueNotFound(_, context),
                                let DecodingError.typeMismatch(_, context)
                    {
                        Logger.firestore.error(
                            "\(loggingKey) decode failed [\(document.documentID, privacy: .public)]: \(context.debugDescription, privacy: .public)"
                        )
                    } catch {
                        Logger.firestore.error(
                            "\(loggingKey) \(diff.type) failed [\(document.documentID, privacy: .public)]: \(error.localizedDescription, privacy: .public)"
                        )
                    }
                }
            }
        }
        listeners.append(listenerRegistration)
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
