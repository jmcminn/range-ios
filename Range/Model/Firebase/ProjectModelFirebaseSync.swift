import Firebase
import FirebaseDatabaseSwift
import Foundation
import OSLog
import RealmSwift

/// Protocol to be adopted by firebase objects that can be stored in Realm
protocol FirebaseToRealmSyncable {
    /// The type used to store the objects in the model Realm db
    associatedtype ModelType: Object
    /// Upsert this element to given Realm. Will be performed in a realm write transaction
    func upsert(_ realm: Realm) throws
}

/// Synchronizes given `ProjectModel` with Firebase Realtime db
class ProjectModelFirebaseSync {
    /// The model to synchronize Firebase with
    private unowned let model: ProjectModel

    /// Background serial queue to perform firebase to Realm sync operations on.
    private let syncQueue = DispatchQueue(label: "firebase-sync-queue")

    /// Firebase database reference
    private let databaseRef: DatabaseReference

    /// Realm used by the sync on the firebaseSyncQueue to update the db with Firebase changes
    private var syncRealm: Realm!

    /// Firebase references
    private lazy var projectSummaryReference = databaseRef.child("projects/\(model.projectId)/summary")
    private lazy var projectDetailsReference = databaseRef.child("projects/\(model.projectId)/details")
    private lazy var statusNamesReference = projectDetailsReference.child("statusNames")
    private lazy var participantsReference = projectDetailsReference.child("participants")
    private lazy var canvasesReference = projectDetailsReference.child("canvases")
    private lazy var geometriesReference = projectDetailsReference.child("geometries")
    private lazy var featuresReference = projectDetailsReference.child("features")
    private lazy var collaborationsReference = projectDetailsReference.child("collaborations")
    private lazy var commentsReference = projectDetailsReference.child("comments")
    private lazy var uploadsReference = projectDetailsReference.child("uploads")

    /// Initialize sync for given `ProjectModel`
    init(model: ProjectModel) {
        self.model = model
        databaseRef = Database.database().reference()
    }

    deinit {
        stop()
    }

    /// Runs given closure on the firebaseSyncQueue as an async function
    func _asyncOnFirebaseSyncQueue(_ closure: @escaping () throws -> Void) async throws {
        try await withUnsafeThrowingContinuation { continuation in
            self.syncQueue.async {
                do {
                    try closure()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } as Void
    }

    /// Starts synchronization - observes all relevant paths and updates the db.
    func start() async throws {
        // create the realm on the syncQueue
        try await _asyncOnFirebaseSyncQueue {
            self.syncRealm = try Realm(configuration: self.model.realmConfig, queue: self.syncQueue)
        }
        // wait for the initial sync of project summary and canvases
        try await doInitialSync()

        // after this point it's only registering for observation and the function returns
        syncDetails(statusNamesReference, as: FirebaseStatusName.self)
        syncDetails(participantsReference, as: FirebaseParticipant.self)
        syncDetails(geometriesReference, as: FirebaseGeometry.self)
        syncDetails(featuresReference, as: FirebaseFeature.self)
        syncDetails(collaborationsReference, as: FirebaseCollaboration.self)
        syncDetails(commentsReference, as: FirebaseComment.self)
        syncDetails(uploadsReference, as: FirebaseUpload.self)
    }

    /// Do the initial sync by observing the single event of type `.value` for project summary and canvases and storing the objects in the model.
    /// We use observe instead of `getData` as this is recommended by Firebase and not forces the server side communication if not needed
    private func doInitialSync() async throws {
        // do this in parallel
        async let projectSummaryRequest = projectSummaryReference._observeSingleEvent(.value)
        async let canvasesRequest = canvasesReference._observeSingleEvent(.value)

        // await for results
        let projectSummarySnapshot = try await projectSummaryRequest
        let canvases = try await canvasesRequest

        // store in the db
        try await _asyncOnFirebaseSyncQueue { [weak self] in
            guard let self = self else { return }
            try self.syncRealm.write {
                let projectSummary = try projectSummarySnapshot.data(as: FirebaseProjectSummary.self)
                try projectSummary.upsert(self.syncRealm)

                for canvasSnapshot in canvases.children {
                    guard let snapshot = canvasSnapshot as? DataSnapshot else { break }
                    let canvas = try snapshot.data(as: FirebasePDFCanvas.self)
                    try canvas.upsert(self.syncRealm)
                }
            }
        }
    }

    /// Convenience function to register listeners for given reference and invoke FirebaseToRealmSyncable methods on decoded objects to update the Realm state.
    ///  - Parameters:
    ///     - dbReference:  the reference to observe for .childAdded, .childChanged and .childRemoved
    ///     - type: the type to use for decoding the firebase SnapshotData for given db reference
    private func syncDetails<T: Decodable & FirebaseToRealmSyncable>(
        _ dbReference: DatabaseReference,
        as type: T.Type
    ) {
        /// Applies the changes from snapshot to Realm
        let syncSnapshot: (Realm, DataEventType, DataSnapshot) throws -> Void = { realm, event, snapshot in
            let firebaseObject = try snapshot.data(as: type)
            try realm.write {
                if event == .childAdded || event == .childChanged {
                    try firebaseObject.upsert(realm)
                } else if event == .childRemoved {
                    guard let object = realm.object(ofType: type.ModelType, forPrimaryKey: snapshot.key)
                    else {
                        return
                    }
                    realm.delete(object)
                } else {
                    throw "Event type \(event) not handled"
                }
            }
        }

        guard let loggingKey = dbReference.key else { fatalError("Reference has no key: \(dbReference)") }
        dbReference._observe(.childAdded, .childChanged, .childRemoved, on: syncQueue) { [weak self] event, snapshot in
            guard let self = self else { return }
            Logger.firebase.debug("\(loggingKey) \(event) \(snapshot.key, privacy: .public)")
            do {
                try syncSnapshot(self.syncRealm, event, snapshot)
            } catch let DecodingError.dataCorrupted(context) {
                Logger.firebase.error(
                    "\(loggingKey) decode failed [\(snapshot.key, privacy: .public)]: \(context.debugDescription, privacy: .public)"
                )
            } catch {
                Logger.firebase.error(
                    "\(loggingKey) \(event) failed [\(snapshot.key, privacy: .public)]: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    /// Deregisters all observers.
    /// Will be called on deinit
    func stop() {
        geometriesReference.removeAllObservers()
    }
}
