import Firebase
import FirebaseDatabaseSwift
import Foundation
import Network
import OSLog
import RealmSwift

/// Protocol to be adopted by firebase objects that can be stored in Realm
protocol FirebaseToRealmSyncable {
    /// The type used to store the objects in the model Realm db
    associatedtype ModelType: Object
    /// Upsert this element with given id to given Realm. Will be performed in a realm write transaction
    func upsert(_ realm: Realm, id: String) throws
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
    lazy var projectSummaryReference = databaseRef.child("projects/\(model.projectId)/summary")
    lazy var projectDetailsReference = databaseRef.child("projects/\(model.projectId)/details")
    lazy var statusNamesReference = projectDetailsReference.child("statusNames")
    lazy var tagNamesReference = projectDetailsReference.child("tagNames")
    lazy var participantsReference = projectDetailsReference.child("participants")
    lazy var canvasesReference = projectDetailsReference.child("canvases")
    lazy var geometriesReference = projectDetailsReference.child("geometries")
    lazy var featuresReference = projectDetailsReference.child("features")
    lazy var collaborationsReference = projectDetailsReference.child("collaborations")
    lazy var commentsReference = projectDetailsReference.child("comments")
    lazy var uploadsReference = projectDetailsReference.child("uploads")

    /// Token for notifications about changes in the actions
    private var actionsNotificationToken: NotificationToken?

    /// maximum backoff for retrying actions (in seconds)
    private let maxBackoff: TimeInterval = 64

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
        syncDetails(tagNamesReference, as: FirebaseTagName.self)
        syncDetails(participantsReference, as: FirebaseParticipant.self)
        syncDetails(geometriesReference, as: FirebaseGeometry.self)
        syncDetails(featuresReference, as: FirebaseFeature.self)
        syncDetails(collaborationsReference, as: FirebaseCollaboration.self)
        syncDetails(commentsReference, as: FirebaseComment.self)
        syncDetails(uploadsReference, as: FirebaseUpload.self)

        /// observe any changes in actions
        try await _asyncOnFirebaseSyncQueue {
            self.actionsNotificationToken = self.syncRealm.objects(Action.self)
                .observe(on: self.syncQueue) { [weak self] changes in
                    guard let self = self else { return }
                    switch changes {
                    case let .initial(actions):
                        self.onActionsChange(actions)
                    case let .update(actions, _, _, _):
                        self.onActionsChange(actions)
                    case let .error(error):
                        Logger.model
                            .error("observing actions failed: \(error.localizedDescription, privacy: .public)")
                    }
                }
        }

//        model.remoteUpdater = self
    }

    /// Do the initial sync by observing the single event of type `.value` for project summary and canvases and storing the objects in the model.
    /// We use observe instead of `getData` as this is recommended by Firebase and not forces the server side communication if not needed
    private func doInitialSync() async throws {
        // do this in parallel
        async let test = projectSummaryReference.getData()
        print("XXX ", try await test)

        async let projectSummaryRequest = projectSummaryReference._observeSingleEvent(.value)
        async let canvasesRequest = canvasesReference._observeSingleEvent(.value)
        async let participantsRequest = participantsReference._observeSingleEvent(.value)

        // await for results
        let projectSummarySnapshot = try await projectSummaryRequest
        let canvases = try await canvasesRequest
        let participants = try await participantsRequest

        // store in the db
        try await _asyncOnFirebaseSyncQueue { [weak self] in
            guard let self = self else { return }
            try self.syncRealm.write {
                let projectSummary = try projectSummarySnapshot.data(as: FirebaseProjectSummary.self)
                try projectSummary.upsert(self.syncRealm, id: projectSummarySnapshot.key)

                for canvasSnapshot in canvases.children {
                    guard let snapshot = canvasSnapshot as? DataSnapshot else { break }
                    let canvas = try snapshot.data(as: FirebasePDFCanvas.self)
                    try canvas.upsert(self.syncRealm, id: snapshot.key)
                }
                for participantSnapshot in participants.children {
                    guard let snapshot = participantSnapshot as? DataSnapshot else { break }
                    let participant = try snapshot.data(as: FirebaseParticipant.self)
                    try participant.upsert(self.syncRealm, id: snapshot.key)
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
                    try firebaseObject.upsert(realm, id: snapshot.key)
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
            } catch let DecodingError.dataCorrupted(context),
                        let DecodingError.keyNotFound(_, context),
                        let DecodingError.valueNotFound(_, context),
                        let DecodingError.typeMismatch(_, context) {
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
        statusNamesReference.removeAllObservers()
        tagNamesReference.removeAllObservers()
        participantsReference.removeAllObservers()
        geometriesReference.removeAllObservers()
        featuresReference.removeAllObservers()
        collaborationsReference.removeAllObservers()
        commentsReference.removeAllObservers()
        uploadsReference.removeAllObservers()

        actionsNotificationToken?.invalidate()
//        model.remoteUpdater = nil
    }
}

// TODO: 44 change into docs:
// 0. listen (realm way) for actions and go to 1.
// 1. get action
// 2. check retry count/etc and run it or (re)set a timer
// 2a. on success remove the action and repeat
// 2b. on failure adjust retry count, next attempt and set a timer
// TODO: 44 add network conditions
extension ProjectModelFirebaseSync {
    /// Potentially trigger the Firebase write on actions update
    /// Performed on the syncQueue
    func onActionsChange(_ actions: Results<Action>) {
        // TODO: 44 how to test it?

        if let action = actions.first {
            do {
                if try maybePerformAction(action) {
                    // successfully performed, delete it
                    syncRealm.delete(action)
                }
            } catch {
                Logger.firebase.error("action failed: \(error.localizedDescription, privacy: .public)")
                action.retryCount += 1
                action.lastErrorMessage = error.localizedDescription
                // TODO: 44 move to some external "exponential backoff" calculator (?)
                action.nextAttemptAt = Date.now.timeIntervalSince1970
                    + min(pow(2, Double(action.retryCount)), maxBackoff)
            }
        }
    }

    // TODO: 44 only try if there's network access
    /// Perform action if retry conditions are met
    /// - Returns: `true` if it was performed
    func maybePerformAction(_: Action) throws -> Bool {
        // TODO: 44 NWPathMonitor for connection monitoring?
//        guard action.shouldPerform(at: Date.now.timeIntervalSince1970) else { return false }
//        try action.command.firebaseCommand.applyToFirebase(firebaseSync: self, in: syncRealm)
        true
    }
}

// extension ProjectModelFirebaseSync: ProjectModelRemoteUpdater {
//    func runActionCommand(_ command: ActionCommand, in realm: Realm) async throws {
//        try await command.firebaseCommand.applyToFirebase(firebaseSync: self, in: realm)
//    }
// }
