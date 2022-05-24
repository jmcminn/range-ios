import Firebase
import FirebaseDatabaseSwift
import Foundation
import RealmSwift

/// Synchronizes given `ProjectModel` with Firebase Realtime db
class ProjectModelFirebaseSync {
    /// The model to synchronize Firebase with
    unowned let model: ProjectModel

    /// Background serial queue to perform firebase to Realm sync operations on.
    // TODO: 38 is the queue needed?
//    let firebaseSyncQueue = DispatchQueue(label: "firebase-sync-queue")

    /// Firebase database handle
    let database: Database

    /// Firebase paths
    private lazy var projectSummaryReference = database
        .reference(withPath: "projects/\(model.projectId)/summary")
    private lazy var canvasesReference = database
        .reference(withPath: "projects/\(model.projectId)/details/canvases")

    /// Initialize sync for given `ProjectModel`
    init(model: ProjectModel) {
        self.model = model
        database = Database.database()
    }

    /// Do the initial sync by using `getData` on all the needed references and storing the objects in the model.
    func doInitialSync() async throws {
        // do this in parallel
        async let projectSummaryRequest = projectSummaryReference.getData()
        async let canvasesRequest = canvasesReference.getData()

        // handle summary
        let projectSummaryData = try await projectSummaryRequest
        let projectSummary = try projectSummaryData.data(as: FirebaseProjectSummary.self).projectSummary
        // handle canvases
        let canvasesData = try await canvasesRequest
        let canvases: [PDFCanvas] = canvasesData.children.compactMap {
            guard let canvasSnapshot = $0 as? DataSnapshot else { return nil }
            do {
                return try canvasSnapshot.data(as: FirebasePDFCanvas.self).pdfCanvas
            } catch {
                print("error decoding canvas snapshot: \(error)")
                return nil
            }
        }

        // store all things
        let realm = try await Realm(configuration: model.realmConfig)
        try realm.write {
            realm.add(projectSummary, update: .modified)
            realm.add(canvases, update: .modified)
        }
    }

    // TODO: 38 start/stop syncing

    deinit {
        // TODO: 38
//        projectSummaryReference.removeAllObservers()
    }
}
