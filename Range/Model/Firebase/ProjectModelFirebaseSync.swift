import Firebase
import FirebaseDatabaseSwift
import Foundation
import OSLog
import RealmSwift

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
    private lazy var statusNamesReference = databaseRef.child("projects/\(model.projectId)/details/statusNames")
    private lazy var canvasesReference = databaseRef.child("projects/\(model.projectId)/details/canvases")
    private lazy var geometriesReference = databaseRef.child("projects/\(model.projectId)/details/geometries")
    private lazy var featuresReference = databaseRef.child("projects/\(model.projectId)/details/features")
    private lazy var collaborationsReference = databaseRef.child("projects/\(model.projectId)/details/collaborations")

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
        syncDetails(statusNamesReference,
                    upsert: { [weak self] in try self?._upsertStatus($0) },
                    remove: { [weak self] in try self?._removeStatus($0) })
        syncDetails(geometriesReference,
                    upsert: { [weak self] in try self?._upsertGeometry($0) },
                    remove: { [weak self] in try self?._removeGeometry($0) })
        syncDetails(featuresReference,
                    upsert: { [weak self] in try self?._upsertFeature($0) },
                    remove: { [weak self] in try self?._removeFeature($0) })
        syncDetails(collaborationsReference,
                    upsert: { [weak self] in try self?._upsertCollaboration($0) },
                    remove: { [weak self] in try self?._removeCollaboration($0) })
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

    /// Convenience function to register listeners for given reference and invoke provided functions on changes
    /// - Parameters:
    ///     - dbReference:  the reference to observe for .childAdded, .childChanged and .childRemoved
    ///     - upsert:             invoked on .childAdded and .childChanged
    ///     - remove:           invoked on .childRemoved
    private func syncDetails(
        _ dbReference: DatabaseReference,
        upsert: @escaping (DataSnapshot) throws -> Void,
        remove: @escaping (DataSnapshot) throws -> Void
    ) {
        guard let loggingKey = dbReference.key else { fatalError("Reference has no key: \(dbReference)") }
        dbReference._observe(.childAdded, .childChanged, .childRemoved, on: syncQueue) { [weak self] event, snapshot in
            guard let self = self else { return }
            Logger.firebase.debug("\(loggingKey) \(event) \(snapshot.key, privacy: .public)")
            do {
                try self.realm.write {
                    switch event {
                    case .childAdded, .childChanged: try upsert(snapshot)
                    case .childRemoved: try remove(snapshot)
                    default: fatalError("Event type \(event) not handled")
                    }
                }
            } catch let DecodingError.dataCorrupted(context) {
                Logger.firebase
                    .error(
                        "\(loggingKey) decode failed [\(snapshot.key, privacy: .public)]: \(context.debugDescription, privacy: .public)"
                    )
            } catch {
                Logger.firebase
                    .error(
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
            Logger.firebase.error("upsertCanvas failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Add or update status.
    /// If decoding fails for a status name it is ignored
}

// MARK: - sync statuses

/// - Warning: All functions should be run on the firebaseSyncQueue in a realm write transaction
extension ProjectModelFirebaseSync {
    /// Add or update a status. It fails with warning only
    private func _upsertStatus(_ snapshot: DataSnapshot) throws {
        let status = try snapshot.data(as: FirebaseStatusName.self).status
        realm.add(status, update: .modified)
    }

    /// Remove the feature
    private func _removeStatus(_ snapshot: DataSnapshot) throws {
        let firebaseStatus = try snapshot.data(as: FirebaseStatusName.self)
        guard let status = realm.object(
            ofType: Status.self,
            forPrimaryKey: firebaseStatus.id
        ) else { return }
        realm.delete(status)
    }
}

// MARK: - geometries sync

/// - Warning: All functions should be run on the firebaseSyncQueue in a realm write transaction
extension ProjectModelFirebaseSync {
    /// Add or update the geometry. It fails with warning only
    private func _upsertGeometry(_ snapshot: DataSnapshot) throws {
        let firebaseGeometry = try snapshot.data(as: FirebaseGeometry.self)
        guard let canvas = realm.object(ofType: PDFCanvas.self, forPrimaryKey: firebaseGeometry.canvasId) else {
            throw "canvas not found \(firebaseGeometry.canvasId)"
        }
        let geometry = firebaseGeometry.geometry
        realm.add(geometry, update: .modified)
        canvas.geometries.insert(geometry)
    }

    // TODO: 38 remove everything "below" ?? web doesn't do it currently...
    /// Remove the geometry
    private func _removeGeometry(_ snapshot: DataSnapshot) throws {
        let firebaseGeometry = try snapshot.data(as: FirebaseGeometry.self)
        guard let geometry = realm.object(
            ofType: Geometry.self,
            forPrimaryKey: firebaseGeometry.geometry.id
        ) else { return }
        realm.delete(geometry)
    }
}

// MARK: - sync features

/// - Warning: All functions should be run on the firebaseSyncQueue in a realm write transaction
extension ProjectModelFirebaseSync {
    /// Add or update the feature. It fails with warning only
    private func _upsertFeature(_ snapshot: DataSnapshot) throws {
        let firebaseFeature = try snapshot.data(as: FirebaseFeature.self)
        guard let geometry = realm.object(ofType: Geometry.self, forPrimaryKey: firebaseFeature.geometryId) else {
            throw "geometry not found \(firebaseFeature.geometryId)"
        }
        let feature = firebaseFeature.feature
        realm.add(feature, update: .modified)
        geometry.features.insert(feature)
    }

    /// Remove the feature
    private func _removeFeature(_ snapshot: DataSnapshot) throws {
        let firebaseFeature = try snapshot.data(as: FirebaseFeature.self)
        guard let feature = realm.object(
            ofType: Feature.self,
            forPrimaryKey: firebaseFeature.id
        ) else { return }
        realm.delete(feature)
    }
}

// MARK: - sync collaborations

/// - Warning: All functions should be run on the firebaseSyncQueue in a realm write transaction
extension ProjectModelFirebaseSync {
    /// Add or update a collaboration. It fails with warning only
    private func _upsertCollaboration(_ snapshot: DataSnapshot) throws {
        let firebaseCollaboration = try snapshot.data(as: FirebaseCollaboration.self)
        guard let feature = realm.object(ofType: Feature.self, forPrimaryKey: firebaseCollaboration.featureId) else {
            throw "feature not found \(firebaseCollaboration.featureId)"
        }
        guard let status = realm.object(ofType: Status.self, forPrimaryKey: firebaseCollaboration.statusId) else {
            throw "status not found \(firebaseCollaboration.statusId)"
        }
        let collaboration = firebaseCollaboration.collaboration
        realm.add(collaboration, update: .modified)
        feature.collaborations.insert(collaboration)
        status.collaborations.insert(collaboration)
    }

    /// Remove the collaboration
    private func _removeCollaboration(_ snapshot: DataSnapshot) throws {
        let firebaseCollaboration = try snapshot.data(as: FirebaseCollaboration.self)
        guard let collaboration = realm.object(
            ofType: Collaboration.self,
            forPrimaryKey: firebaseCollaboration.id
        ) else { return }
        realm.delete(collaboration)
    }
}
