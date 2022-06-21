import CoreLocation
@testable import Range
import RealmSwift
import XCTest

class ProjectModelTest: XCTestCase {
    var model: ProjectModel!

    override func setUpWithError() throws {
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(userId: "user1", projectId: UUID().uuidString, inMemory: true)
    }

    override func tearDownWithError() throws {}

    func testIsProjectDownloaded_emptyProject() throws {
        XCTAssertFalse(model.isProjectDownloaded())
    }

    func testIsProjectDownloaded_summaryAndCurrentUserPresent() throws {
        try model.mainRealm.write {
            model.mainRealm.add(ProjectSummary(id: model.projectId, center:
                CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
            model.mainRealm.add(Participant(id: "user1", firstName: "", lastName: "",
                                            avatarUrl: nil, email: ""))
        }
        XCTAssertTrue(model.isProjectDownloaded())
    }

    func testLoadProject_emptyProject() throws {
        XCTAssertThrowsError(
            try model.loadProject()
        ) { error in
            guard
                let error = error as? ModelError
            else {
                XCTFail("unexpected error: \(error)"); return
            }
            XCTAssertEqual(error, ModelError.summaryNotFound)
        }
    }

    func testLoadProject_noCurrentUser() throws {
        try model.mainRealm.write {
            model.mainRealm.add(ProjectSummary(id: model.projectId, center:
                CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        }
        XCTAssertThrowsError(
            try model.loadProject()
        ) { error in
            guard
                let error = error as? ModelError
            else {
                XCTFail("unexpected error: \(error)"); return
            }
            XCTAssertEqual(error, ModelError.currentUserNotFound)
        }
    }

    func testLoadProject_summaryAndCurrentUserPresent() throws {
        try model.mainRealm.write {
            model.mainRealm.add(ProjectSummary(id: model.projectId, center:
                CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
            model.mainRealm.add(Participant(id: "user1", firstName: "", lastName: "",
                                            avatarUrl: nil, email: ""))
        }
        try model.loadProject()
        XCTAssertEqual(model.projectSummary.id, model.projectId)
        XCTAssertEqual(model.projectSummary.center.longitude, -96.5, accuracy: 0.000000001)
    }
}
