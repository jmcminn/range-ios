import CoreLocation
@testable import Range
import RealmSwift
import Turf
import XCTest

class AddStatusCommandTest: XCTestCase {
    var pendingUploadsModel: PendingUploadsModel!
    var model: ProjectModel!
    var realm: Realm!

    @MainActor
    override func setUpWithError() throws {
        pendingUploadsModel = TestPendingUploadsModel()
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(
            userId: "user1",
            projectId: UUID().uuidString,
            imageCaches: ImageCaches(projectId: ""),
            pendingUploadsModel: pendingUploadsModel,
            inMemory: true
        )
        realm = model.mainRealm
    }

    // Tests the add/update command
    func testApplyInRealm() throws {
        // 1. initial status
        var command = AddStatusCommand(
            statusId: "status1",
            name: "In progress",
            color: "#123456",
            isInitial: true,
            isCompleted: false
        )

        // when creating initial status
        try realm.write {
            try command.apply(inRealm: realm)
        }

        // it gets stored with all properties
        let status = try XCTUnwrap(realm.object(ofType: Status.self, forPrimaryKey: "status1"), "status1 not found")
        XCTAssertEqual(status.name, "In progress")
        XCTAssertEqual(status.color.toHexString(), "#123456")
        XCTAssertEqual(status.isInitial, true)
        XCTAssertEqual(status.isCompleted, false)

        // 2. change the status
        command.name = "In progress..."
        // update the status
        try realm.write {
            try command.apply(inRealm: realm)
        }
        // check status after update
        XCTAssertEqual(status.name, "In progress...")
        XCTAssertEqual(status.color.toHexString(), "#123456")
        XCTAssertEqual(status.isInitial, true)
        XCTAssertEqual(status.isCompleted, false)
    }
}
