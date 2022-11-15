import CoreLocation
@testable import Range
import RealmSwift
import XCTest

class ProjectModelTest: XCTestCase {
    let pendingUploadsModel = TestPendingUploadsModel()
    var model: ProjectModel!
    var realm: Realm!

    override func setUpWithError() throws {
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(
            userId: "user1",
            projectId: UUID().uuidString,
            imageCaches: ImageCaches(),
            pendingUploadsModel: pendingUploadsModel,
            inMemory: true
        )
        realm = model.mainRealm
    }

    override func tearDownWithError() throws {}

    func testLoadProject_emptyProject() throws {
        XCTAssertThrowsError(
            try model.loadProject(initialCanvasId: "canvas1")
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.summaryNotFound)
        }
    }

    func testLoadProject_noCurrentUser() throws {
        try realm.write {
            realm.add(ProjectSummary(id: model.projectId, name: "", center:
                CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        }
        XCTAssertThrowsError(
            try model.loadProject(initialCanvasId: "canvas1")
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.currentUserNotFound)
        }
    }

    func testLoadProject_noCanvas() throws {
        try realm.write {
            realm.add(ProjectSummary(id: model.projectId, name: "project name", center:
                CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
            realm.add(Participant(id: "user1", firstName: "", lastName: "", avatarUrl: nil, email: ""))
        }
        XCTAssertThrowsError(
            try model.loadProject(initialCanvasId: "canvas1")
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.canvasNotFound)
        }
    }

    func testLoadProject_successful() throws {
        try realm.write {
            realm.add(ProjectSummary(id: model.projectId, name: "project name", center:
                CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
            realm.add(Participant(id: "user1", firstName: "", lastName: "", avatarUrl: nil, email: ""))
            realm.add(PDFCanvas(id: "canvas1", pageNumber: 0, userDefinedScale: 1))
        }
        try model.loadProject(initialCanvasId: "canvas1")
        XCTAssertEqual(model.projectSummary.id, model.projectId)
        XCTAssertEqual(model.projectSummary.name, "project name")
        XCTAssertEqual(model.projectSummary.center.longitude, -96.5, accuracy: 0.000000001)
    }
}
