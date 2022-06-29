import FirebaseFirestore
import FirebaseFirestoreSwift
import Foundation
import OSLog
import RealmSwift

class ProjectModelFirestoreSync {
    /// The model to synchronize Firebase with
    private unowned let model: ProjectModel

    /// Background serial queue to perform firebase to Realm sync operations on.
    private let syncQueue = DispatchQueue(label: "firestore-sync-queue")

    /// Realm used by the sync on the syncQueue to update the db with Firebase changes
    private var syncRealm: Realm!

    /// Firestore reference
    let firestore: Firestore

    lazy var projectRef = firestore.document("projects/\(model.projectId)")
    lazy var canvasesRef = projectRef.collection("canvases")
    lazy var collaborationsRef = projectRef.collection("collaborations")
    lazy var commentsRef = projectRef.collection("comments")
    lazy var featuresRef = projectRef.collection("features")
    lazy var geometriesRef = projectRef.collection("geometries")
    lazy var participantsRef = projectRef.collection("participants")
    lazy var statusNamesRef = projectRef.collection("statusNames")
    lazy var tagNamesRef = projectRef.collection("tagNames")
    lazy var uploadsRef = projectRef.collection("uploads")

    var listerners: [ListenerRegistration] = []

    /// Initialize sync for given `ProjectModel`
    init(model: ProjectModel) {
        self.model = model
        firestore = Firestore.firestore()
    }

    deinit {
        stop()
    }

    /// Starts synchronization - observes all relevant paths and updates the db.
    func start() async throws {
        // wait for the initial sync of the required data
        try await doInitialSync()

        // after this point it's only registering for observation and the function returns
        syncDetails(statusNamesRef, as: FirebaseStatusName.self)
        syncDetails(tagNamesRef, as: FirebaseTagName.self)
        syncDetails(participantsRef, as: FirebaseParticipant.self)
        syncDetails(geometriesRef, as: FirebaseGeometry.self)
        syncDetails(featuresRef, as: FirebaseFeature.self)
        syncDetails(collaborationsRef, as: FirebaseCollaboration.self)
        syncDetails(commentsRef, as: FirebaseComment.self)
        syncDetails(uploadsRef, as: FirebaseUpload.self)

        // register itself as a remote updates for the model
        model.remoteUpdater = self
    }

    /// Do the initial sync by getting the documents for project summary and canvases and storing the objects in the model.
    private func doInitialSync() async throws {
        // do this in parallel
        async let projectSummaryRequest = projectRef.getDocument(as: FirebaseProjectSummary.self)
        async let canvasesRequest = canvasesRef.getDocuments()
        async let participantsRequest = participantsRef.getDocuments()

        // await for results
        let projectSummary = try await projectSummaryRequest
        let canvases = try await canvasesRequest
        let participants = try await participantsRequest

        // store in the db
        try await _asyncWrite { realm in
            try projectSummary.upsert(realm)
            try canvases.documents.forEach {
                let canvas = try $0.data(as: FirebasePDFCanvas.self)
                try canvas.upsert(realm)
            }
            try participants.documents.forEach {
                let participant = try $0.data(as: FirebaseParticipant.self)
                try participant.upsert(realm)
            }
        }
    }

    /// Convenience function to register listeners for given reference and invoke FirebaseToRealmSyncable methods on decoded objects to update the Realm state.
    ///  - Parameters:
    ///     - collectionRef:  the collection to observe for .childAdded, .childChanged and .childRemoved
    ///     - type: the type to use for decoding the firebase SnapshotData for given db reference
    private func syncDetails<T: Decodable & FirebaseToRealmSyncable>(
        _ collectionRef: CollectionReference,
        as type: T.Type
    ) {
        /// Applies the changes from document to Realm
        let syncDocument: (Realm, DocumentChangeType, QueryDocumentSnapshot) throws
            -> Void = { realm, changeType, snapshot in
                let firebaseObject = try snapshot.data(as: type)
                try realm.write {
                    if changeType == .added || changeType == .modified {
                        try firebaseObject.upsert(realm)
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
            self.syncQueue.async {
                snapshot.documentChanges.forEach { diff in
                    let document = diff.document
                    Logger.firestore.debug("\(loggingKey) \(diff.type) \(document.documentID, privacy: .public)")
                    do {
                        try syncDocument(self.syncRealm, diff.type, document)
                    } catch let DecodingError.dataCorrupted(context),
                                let DecodingError.keyNotFound(_, context),
                                let DecodingError.valueNotFound(_, context),
                                let DecodingError.typeMismatch(_, context) {
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
        listerners.append(listenerRegistration)
    }

    /// Deregisters all observers.
    /// Will be called on deinit
    func stop() {
        listerners.forEach { $0.remove() }
        listerners.removeAll()
    }
}

extension ProjectModelFirestoreSync: ProjectModelRemoteUpdater {
    func runCommand(_ command: Command, writer: ProjectModelWriter) async throws -> Bool {
        if let command = command as? FirestoreCommand {
            try await command.applyToFirestore(firestoreSync: self, writer: writer)
            return true
        }
        return false
    }

    func runActionCommand(_ command: ActionCommand, writer: ProjectModelWriter) async throws {
        try await command.firestoreCommand.applyToFirestore(firestoreSync: self, writer: writer)
    }
}

extension ProjectModelFirestoreSync {
    /// Runs given closure on the writeQueue in the writeRealm transaction as an async function
    func _asyncWrite(_ closure: @escaping (Realm) throws -> Void) async throws {
        try await withUnsafeThrowingContinuation { continuation in
            self.syncQueue.async { [self] in
                do {
                    if syncRealm == nil {
                        syncRealm = try Realm(configuration: model.realmConfig, queue: syncQueue)
                    }
                    // at this point writeRealm is set or it threw an error
                    try syncRealm!.write {
                        try closure(syncRealm!)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } as Void
    }
}
