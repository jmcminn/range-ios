@testable import Range
import RealmSwift
import XCTest

/// Superclass for tests that need access to ProjectModel, contains some common properties and setup code
class ProjectModelTestCase: XCTestCase {
    let pendingUploadsModel = TestPendingUploadsModel()
    let pendingActionsModel = TestPendingActionsModel()
    var model: ProjectModel!
    var realm: Realm!

    @MainActor
    override func setUpWithError() throws {
        let localFiles = try LocalFiles()
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(
            userId: "user1",
            projectId: UUID().uuidString,
            localFiles: localFiles,
            mediaCache: MediaCache(localFiles: localFiles),
            pendingUploadsModel: pendingUploadsModel,
            pendingActionsModel: pendingActionsModel,
            inMemory: true
        )
        realm = model.mainRealm
    }
}
