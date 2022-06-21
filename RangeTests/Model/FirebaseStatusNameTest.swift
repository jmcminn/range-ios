import CoreLocation
@testable import Range
import RealmSwift
import Turf
import XCTest

class FirebaseStatusNameRealmSyncTest: XCTestCase {
    var model: ProjectModel!
    var realm: Realm!

    override func setUpWithError() throws {
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(userId: "user1", projectId: UUID().uuidString, inMemory: true)
        realm = model.mainRealm
    }

    // Tests how upserting/removing the FirebaseStatusName is reflected in the Realm db
    func testStatusSync() throws {
        // 1. initial status
        var firebaseStatus = FirebaseStatusName(
            id: "status1",
            name: "In progress",
            color: "#123456",
            isInitial: true,
            isCompleted: false
        )

        // when creating initial status
        try realm.write {
            try firebaseStatus.upsert(realm)
        }

        // it gets stored with all properties
        guard let status = realm.object(ofType: Status.self, forPrimaryKey: "status1") else {
            throw "status1 not found"
        }
        XCTAssertEqual(status.name, "In progress")
        XCTAssertEqual(status.color.toHexString(), "#123456")
        XCTAssertEqual(status.isInitial, true)
        XCTAssertEqual(status.isCompleted, false)

        // 2. change the status
        firebaseStatus.name = "In progress..."
        // update the status
        try realm.write {
            try firebaseStatus.upsert(realm)
        }
        // check status after update
        XCTAssertEqual(status.name, "In progress...")
        XCTAssertEqual(status.color.toHexString(), "#123456")
        XCTAssertEqual(status.isInitial, true)
        XCTAssertEqual(status.isCompleted, false)
    }
}
