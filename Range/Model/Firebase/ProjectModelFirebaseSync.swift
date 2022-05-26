import Firebase
import FirebaseDatabaseSwift
import Foundation
import RealmSwift

/// Synchronizes given `ProjectModel` with Firebase Realtime db
class ProjectModelFirebaseSync {
    /// The model to synchronize Firebase with
    private unowned let model: ProjectModel

    /// Background serial queue to perform firebase to Realm sync operations on.
    private let firebaseSyncQueue = DispatchQueue(label: "firebase-sync-queue")

    /// Firebase database handle
    private let database: Database

    /// Array of handles for firebase listeners
    private var databaseHandles = Set<DatabaseHandle>()

    /// Realm used by the sync on the firebaseSyncQueue to update the db with Firebase changes
    private var realm: Realm!

    /// Firebase paths
    private lazy var projectSummaryReference = database
        .reference(withPath: "projects/\(model.projectId)/summary")
    private lazy var canvasesReference = database
        .reference(withPath: "projects/\(model.projectId)/details/canvases")
    private lazy var geometriesReference = database
        .reference(withPath: "projects/\(model.projectId)/details/geometries")

    /// Initialize sync for given `ProjectModel`
    init(model: ProjectModel) {
        self.model = model
        database = Database.database()
    }

    deinit {
        stop()
    }

    /// Do the initial sync by using `getData` on all the needed references and storing the objects in the model.
    func doInitialSync() async throws {
        // do this in parallel
        async let projectSummaryRequest = projectSummaryReference.getData()
        async let canvasesRequest = canvasesReference.getData()
        async let geometriesRequest = geometriesReference.getData()

        // await for results and convert to Realm objects
        let projectSummary = try convertProjectSummaryData(try await projectSummaryRequest)
        let canvases = convertCanvasesData(try await canvasesRequest)
        let geometries = convertGeometriesData(try await geometriesRequest)

        // store in the db
        let realm = try await Realm(configuration: model.realmConfig)
        try realm.write {
            realm.add(projectSummary, update: .modified)
            realm.add(canvases, update: .modified)

            for (canvasId, geometries) in geometries {
                realm.add(geometries, update: .modified)
                if let canvas = realm.object(ofType: PDFCanvas.self, forPrimaryKey: canvasId) {
                    for geometry in geometries {
                        if !canvas.geometries.contains(where: { $0.id == geometry.id }) {
                            canvas.geometries.insert(geometry)
                        }
                    }
                }
            }
        }
    }

    private func _canvas(byId canvasId: String) -> PDFCanvas? {
        realm.object(ofType: PDFCanvas.self, forPrimaryKey: canvasId)
    }

    /// Add or update the geometry
    /// To be called on the firebaseSyncQueue
    private func _upsertGeometry(snapshot: DataSnapshot) {
        do {
            try realm.write {
                let firebaseGeometry = try snapshot.data(as: FirebaseGeometry.self)
                guard let canvas = _canvas(byId: firebaseGeometry.canvasId) else { return }
                let geometry = firebaseGeometry.geometry
                realm.add(geometry, update: .modified)
                canvas.geometries.insert(geometry)
            }
        } catch {
            print("error adding geometry: \(error)")
        }
    }

    /// Remove the geometry
    /// To be called on the firebaseSyncQueue
    private func _removeGeometry(snapshot: DataSnapshot) {
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
            print("error removing geometry: \(error)")
        }
    }

    /// Starts synchronization - observes all relevant paths and updates the db.
    func start() {
        firebaseSyncQueue.async {
            do {
                self.realm = try Realm(configuration: self.model.realmConfig, queue: self.firebaseSyncQueue)
            } catch {
                // TODO: 38 add callback to start...
                print("FirebaseSyncRealm creation error: ", error)
            }
        }
        geometriesReference.observe(.childAdded) { [weak self] snapshot in
            print("_addGeometry: ", snapshot)
            guard let self = self else { return }
            self.firebaseSyncQueue.async {
                self._upsertGeometry(snapshot: snapshot)
            }
        }

        geometriesReference.observe(.childRemoved) { [weak self] snapshot in
            print("_removeGeometry: ", snapshot)
            guard let self = self else { return }
            self.firebaseSyncQueue.async {
                self._removeGeometry(snapshot: snapshot)
            }
        }
        geometriesReference.observe(.childChanged) { [weak self] snapshot in
            print("_changeGeometry: ", snapshot)
            guard let self = self else { return }
            self.firebaseSyncQueue.async {
                // same logic as for adding
                self._upsertGeometry(snapshot: snapshot)
            }
        }
    }

    /// Deregisters all observers.
    /// Will be called on deinit
    func stop() {
        geometriesReference.removeAllObservers()
    }

    /// Converts Firebase project summary to `ProjectSummary`.
    /// Throws if cannot be converted
    private func convertProjectSummaryData(_ projectSummaryData: DataSnapshot) throws -> ProjectSummary {
        try projectSummaryData.data(as: FirebaseProjectSummary.self).projectSummary
    }

    /// Converts Firebase canvases snapshot to array of `PDFCanvas`
    /// If decoding fails for a canvas it is ignored
    private func convertCanvasesData(_ canvasesData: DataSnapshot) -> [PDFCanvas] {
        canvasesData.children.compactMap {
            guard let canvasSnapshot = $0 as? DataSnapshot else { return nil }
            do {
                return try canvasSnapshot.data(as: FirebasePDFCanvas.self).pdfCanvas
            } catch {
                print("error decoding canvas snapshot: \(error)")
                return nil
            }
        }
    }

    /// Converts Firebase geometries snapshot to map of [`canvasId`: `Geometry`]
    private func convertGeometriesData(_ geometriesData: DataSnapshot) -> [String: [Geometry]] {
        let firebaseGeometries: [FirebaseGeometry] = geometriesData.children.compactMap {
            guard let snapshot = $0 as? DataSnapshot else { return nil }
            do {
                return try snapshot.data(as: FirebaseGeometry.self)
            } catch {
                print("error decoding geometry snapshot: \(error)")
                return nil
            }
        }
        let r = Dictionary(grouping: firebaseGeometries, by: { $0.canvasId })
        return r.mapValues { firebaseGeometries in
            firebaseGeometries.compactMap { firebaseGeometry in firebaseGeometry.geometry }
        }
    }
}
