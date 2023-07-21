@testable import Range
import RealmSwift
import XCTest

class FirestoreStatusNameTest: ProjectModelTestCase {
    // Test creating/updating the object in local db from Firestore object
    func testUpsert() throws {
        // 1. initial status
        var firestoreStatus = FirestoreStatusName(
            name: "In progress",
            color: "#123456",
            isInitial: true,
            isCompleted: false
        )

        // when creating initial status
        try realm.write {
            try firestoreStatus.upsert(withId: "status1", inRealm: realm)
        }

        // it gets stored with all properties
        let status = try XCTUnwrap(realm.object(ofType: Status.self, forPrimaryKey: "status1"), "status1 not found")
        XCTAssertEqual(status.name, "In progress")
        XCTAssertEqual(status.color.toHexString(), "#123456")
        XCTAssertEqual(status.isInitial, true)
        XCTAssertEqual(status.isCompleted, false)

        // 2. change the status
        firestoreStatus.name = "In progress..."
        // update the status
        try realm.write {
            try firestoreStatus.upsert(withId: "status1", inRealm: realm)
        }
        // check status after update
        XCTAssertEqual(status.name, "In progress...")
        XCTAssertEqual(status.color.toHexString(), "#123456")
        XCTAssertEqual(status.isInitial, true)
        XCTAssertEqual(status.isCompleted, false)
    }
}
