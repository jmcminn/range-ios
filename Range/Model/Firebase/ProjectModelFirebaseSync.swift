import Firebase
import FirebaseDatabaseSwift
import Foundation
import OSLog
import RealmSwift

/// Some helper methods for Firebase DatabaseReference
private extension DatabaseReference {
    /// Wraps observeSingleEvent in an async method that returns the DataSnapshot or throws
    func _observeSingleEvent(_ eventType: DataEventType) async throws -> DataSnapshot {
        try await withUnsafeThrowingContinuation { continuation in
            observeSingleEvent(of: eventType) { snapshot in
                continuation.resume(returning: snapshot)
            } withCancel: { error in
                continuation.resume(throwing: error)
            }
        }
    }

    /// Wraps observe to run the closure on the provided queue
    func _observe(_ eventType: DataEventType, on queue: DispatchQueue, _ closure: @escaping (DataSnapshot) -> Void) {
        observe(eventType) { dataSnapshot in
            queue.async {
                closure(dataSnapshot)
            }
        }
    }
}

/// Synchronizes given `ProjectModel` with Firebase Realtime db
class ProjectModelFirebaseSync {
    /// The model to synchronize Firebase with
    private unowned let model: ProjectModel

    /// Background serial queue to perform firebase to Realm sync operations on.
    private let syncQueue = DispatchQueue(label: "firebase-sync-queue")

    /// Firebase database reference
    private let databaseRef: DatabaseReference

    /// Array of handles for firebase listeners
    private var databaseHandles = Set<DatabaseHandle>()

    /// Realm used by the sync on the firebaseSyncQueue to update the db with Firebase changes
    private var realm: Realm!

    /// Firebase paths
    private lazy var projectSummaryReference = databaseRef.child("projects/\(model.projectId)/summary")
    private lazy var canvasesReference = databaseRef.child("projects/\(model.projectId)/details/canvases")
    private lazy var geometriesReference = databaseRef.child("projects/\(model.projectId)/details/geometries")
    private lazy var featuresReference = databaseRef.child("projects/\(model.projectId)/details/features")

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
            self.realm = try Realm(configuration: self.model.realmConfig, queue: self.syncQueue)
        }
        // wait for the initial sync of project summary and canvases
        try await doInitialSync()

        // after this point it's only registering for observation and the function returns
        geometriesReference._observe(.childAdded, on: syncQueue) { [weak self] in
            Logger.firebase.debug("onGeometryAdded \($0.key, privacy: .public)")
            self?._upsertGeometry($0)
        }
        geometriesReference._observe(.childRemoved, on: syncQueue) { [weak self] in
            Logger.firebase.debug("onGeometryRemoved \($0.key, privacy: .public)")
            self?._removeGeometry($0)
        }
        geometriesReference._observe(.childChanged, on: syncQueue) { [weak self] in
            Logger.firebase.debug("onGeometryChanged \($0.key, privacy: .public)")
            self?._upsertGeometry($0)
        }
        featuresReference._observe(.childAdded, on: syncQueue) { [weak self] in
            Logger.firebase.debug("onFeatureAdded \($0.key, privacy: .public)")
            self?._upsertFeature($0)
        }
        featuresReference._observe(.childRemoved, on: syncQueue) { [weak self] in
            Logger.firebase.debug("onFeatureRemoved \($0.key, privacy: .public)")
            self?._removeFeature($0)
        }
        featuresReference._observe(.childChanged, on: syncQueue) { [weak self] in
            Logger.firebase.debug("onFeatureChanged \($0.key, privacy: .public)")
            self?._upsertFeature($0)
        }
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
            try self._upsertProjectSummary(projectSummarySnapshot)
            for canvasSnapshot in canvases.children {
                guard let snapshot = canvasSnapshot as? DataSnapshot else { break }
                self._upsertCanvas(snapshot)
            }
        }
    }

    /// Deregisters all observers.
    /// Will be called on deinit
    func stop() {
        geometriesReference.removeAllObservers()
    }
}

// MARK: - Model updates from firebase snapshots

/// - Warning: All functions should be run on the firebaseSyncQueue
extension ProjectModelFirebaseSync {
    /// Add or update the project summary. It throws on failure (as project summary is required to proceed)
    private func _upsertProjectSummary(_ snapshot: DataSnapshot) throws {
        try realm.write {
            let projectSummary = try snapshot.data(as: FirebaseProjectSummary.self).projectSummary
            realm.add(projectSummary, update: .modified)
        }
    }

    /// Add or update canvas.
    /// If decoding fails for a canvas it is ignored
    private func _upsertCanvas(_ snapshot: DataSnapshot) {
        do {
            try realm.write {
                let canvas = try snapshot.data(as: FirebasePDFCanvas.self).pdfCanvas
                realm.add(canvas, update: .modified)
            }
        } catch {
            Logger.firebase.error("UpsertCanvas failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Add or update the geometry. It fails with warning only
    private func _upsertGeometry(_ snapshot: DataSnapshot) {
        do {
            try realm.write {
                let firebaseGeometry = try snapshot.data(as: FirebaseGeometry.self)
                guard let canvas = realm.object(ofType: PDFCanvas.self, forPrimaryKey: firebaseGeometry.canvasId)
                else {
                    Logger.firebase
                        .error(
                            "upsertGeometry failed [\(firebaseGeometry.geometry.id, privacy: .public)]: canvas not found [\(firebaseGeometry.canvasId, privacy: .public)]"
                        )
                    return
                }
                let geometry = firebaseGeometry.geometry
                realm.add(geometry, update: .modified)
                canvas.geometries.insert(geometry)
            }
        } catch let DecodingError.dataCorrupted(context) {
            Logger.firebase
                .error(
                    "decodeGeometry failed [\(snapshot.key, privacy: .public)]: \(context.debugDescription, privacy: .public)"
                )
        } catch {
            Logger.firebase
                .error(
                    "upsertGeometry failed [\(snapshot.key, privacy: .public)]: \(error.localizedDescription, privacy: .public)"
                )
        }
    }

    // TODO: 38 remove everything "below" ?? web doesn't do it currently...
    /// Remove the geometry
    private func _removeGeometry(_ snapshot: DataSnapshot) {
        do {
            try realm.write {
                let firebaseGeometry = try snapshot.data(as: FirebaseGeometry.self)
                guard let geometry = realm.object(
                    ofType: Geometry.self,
                    forPrimaryKey: firebaseGeometry.geometry.id
                ) else { return }
                realm.delete(geometry)
            }
        } catch {
            Logger.firebase.error("removeGeometry failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Add or update the feature. It fails with warning only
    private func _upsertFeature(_ snapshot: DataSnapshot) {
        do {
            try realm.write {
                let firebaseFeature = try snapshot.data(as: FirebaseFeature.self)
                guard let geometry = realm.object(ofType: Geometry.self, forPrimaryKey: firebaseFeature.geometryId)
                else {
                    Logger.firebase
                        .error(
                            "upsertFeature failed [\(firebaseFeature.feature.id, privacy: .public)]: geometry not found [\(firebaseFeature.geometryId, privacy: .public)]"
                        )
                    return
                }
                let feature = firebaseFeature.feature
                realm.add(feature, update: .modified)
                geometry.features.insert(feature)
            }
        } catch {
            Logger.firebase.error("upsertFeature failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Remove the feature
    private func _removeFeature(_ snapshot: DataSnapshot) {
        do {
            try realm.write {
                let firebaseFeature = try snapshot.data(as: FirebaseFeature.self)
                guard let feature = realm.object(
                    ofType: Feature.self,
                    forPrimaryKey: firebaseFeature.feature.id
                ) else { return }
                realm.delete(feature)
            }
        } catch {
            Logger.firebase.error("removeFeature failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
