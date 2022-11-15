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
    func upsertCommand(id: String) throws -> Command
}

/// A context for firestore commands. It stores the current projectId and provides the references to all the project collections.
class ProjectModelFirestoreContext {
    let projectId: String
    private unowned let firestore: Firestore

    lazy var projectRef = firestore.document("projects/\(projectId)")
    lazy var canvasesRef = projectRef.collection("canvases")
    lazy var collaborationsRef = projectRef.collection("collaborations")
    lazy var commentsRef = projectRef.collection("comments")
    lazy var featuresRef = projectRef.collection("features")
    lazy var geometriesRef = projectRef.collection("geometries")
    lazy var participantsRef = projectRef.collection("participants")
    lazy var statusNamesRef = projectRef.collection("statusNames")
    lazy var tagNamesRef = projectRef.collection("tagNames")
    lazy var updatesRef = projectRef.collection("updates")
    lazy var uploadsRef = projectRef.collection("uploads")

    init(firestore: Firestore, projectId: String) {
        self.firestore = firestore
        self.projectId = projectId
    }
}

//
//          applyLocally                         upsertCmd                       decode
// Realm  <--------------                      <-----------                    <--------
//                         AddGeometryCommand                FirebaseGeometry             Firestore
// Memory  ------------->                      ----------->                    --------->
//          addGeometry                         applyToFirestore                encode + save

/// This object provides the way to sync Firestore backend data with local Realm db.
class ProjectModelFirestoreSync {
    /// The model to synchronize Firebase with
    private unowned let model: ProjectModel
    private let ctx: ProjectModelFirestoreContext

    /// Firestore reference
    let firestore: Firestore

    var listeners: [ListenerRegistration] = []

    /// Initialize sync for given `ProjectModel`
    init(model: ProjectModel) {
        self.model = model
        firestore = Firestore.firestore()
        ctx = ProjectModelFirestoreContext(firestore: firestore, projectId: model.projectId)
    }

    deinit {
        stop()
    }

    /// Starts synchronization - observes all relevant paths and updates the db.
    func start() async throws {
        // wait for the initial sync of the required data
        try await doInitialSync()

        // after this point it's only registering for observation and the function returns
        syncDetails(ctx.statusNamesRef, as: FirebaseStatusName.self)
        syncDetails(ctx.tagNamesRef, as: FirebaseTagName.self)
        syncDetails(ctx.participantsRef, as: FirebaseParticipant.self)
        syncDetails(ctx.geometriesRef, as: FirebaseGeometry.self)
        syncDetails(ctx.featuresRef, as: FirebaseFeature.self)
        syncDetails(ctx.collaborationsRef, as: FirebaseCollaboration.self)
        syncDetails(ctx.commentsRef, as: FirebaseComment.self)
        syncDetails(ctx.updatesRef, as: FirebaseUpdate.self)
        syncDetails(ctx.uploadsRef, as: FirebaseUpload.self)

        // register itself as a remote updates for the model
        model.remoteUpdater = self
    }

    /// Do the initial sync by getting the documents for project summary and canvases and storing the objects in the model.
    private func doInitialSync() async throws {
        // do this in parallel
        async let projectSummaryRequest = ctx.projectRef.getDocument(as: FirebaseProjectSummary.self)
        async let canvasesRequest = ctx.canvasesRef.getDocuments()
        async let participantsRequest = ctx.participantsRef.getDocuments()

        // await for results
        let projectSummary = try await projectSummaryRequest
        let canvases = try await canvasesRequest
        let participants = try await participantsRequest

        // store in the db
        try await model.write { realm in
            try projectSummary.upsertCommand(id: self.model.projectId).apply(inRealm: realm)
            try canvases.documents.forEach {
                let canvas = try $0.data(as: FirebasePDFCanvas.self)
                try canvas.upsertCommand(id: $0.documentID).apply(inRealm: realm)
            }
            try participants.documents.forEach {
                let participant = try $0.data(as: FirebaseParticipant.self)
                try participant.upsertCommand(id: $0.documentID).apply(inRealm: realm)
            }
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
                        try firebaseObject.upsertCommand(id: snapshot.documentID).apply(inRealm: realm)
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

/// Implementation of the remote updater protocol.
/// ProjectModelFirestoreSync registers itself as a remote updater in ProjectModel, so all the update commands are executed
/// against the Firestore
extension ProjectModelFirestoreSync: ProjectModelRemoteUpdater {
    /// Runs given commands in firestore transaction.
    /// It is assumed that *all* the commands support applying in Firestore transaction by implementing the `FirestoreCommand`
    /// protocol. If that's not the case this method will crash.
    func runCommands(_ commands: [Command], writer _: ProjectModelWriter) async throws {
        try await firestore.runTransaction { transaction, errorPointer -> Any? in
            for command in commands {
                do {
                    try (command as! FirestoreCommand).apply(inFirestoreTransaction: transaction, context: self.ctx)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return false
                }
            }
            // don't return nil, it's supposed to work but it crashes
            return true
        }
    }
}
