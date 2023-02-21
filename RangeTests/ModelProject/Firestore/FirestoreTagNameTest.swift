@testable import Range
import RealmSwift
import XCTest

class FirestoreTagNameTest: XCTestCase {
    let pendingUploadsModel = TestPendingUploadsModel()
    let pendingActionsModel = TestPendingActionsModel()
    var model: ProjectModel!
    var realm: Realm!

    @MainActor
    override func setUpWithError() throws {
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(
            userId: "user1",
            projectId: UUID().uuidString,
            localFiles: LocalFiles(),
            pendingUploadsModel: pendingUploadsModel,
            pendingActionsModel: pendingActionsModel,
            inMemory: true
        )
        realm = model.mainRealm
    }

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
