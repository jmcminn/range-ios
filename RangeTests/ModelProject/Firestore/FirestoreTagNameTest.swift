@testable import Range
import RealmSwift
import XCTest

class FirestoreTagNameTest: ProjectModelTestCase {
    // Test creating/updating the object in local db from Firestore object
    func testUpsert() throws {
        // 1. initial tag
        var firestoreTagName = FirestoreTagName(name: "kitchen")

        // when creating initial tag
        try realm.write {
            try firestoreTagName.upsert(withId: "tag1", inRealm: realm)
        }

        // it gets stored with all properties
        let tag = try XCTUnwrap(realm.object(ofType: Tag.self, forPrimaryKey: "tag1"), "tag1 not found")
        XCTAssertEqual(tag.name, "kitchen")

        // 2. change the tag
        firestoreTagName.name = "kitchen..."
        // update object
        try realm.write {
            try firestoreTagName.upsert(withId: "tag1", inRealm: realm)
        }
        // check status after update
        XCTAssertEqual(tag.name, "kitchen...")
    }
}
