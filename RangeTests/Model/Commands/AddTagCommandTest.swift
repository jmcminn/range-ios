import CoreLocation
@testable import Range
import RealmSwift
import Turf
import XCTest

class AddTagCommandTest: XCTestCase {
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

    func testApplyInRealm() throws {
        // 1. initial tag
        var cmd = AddTagCommand(tagId: "tag1", name: "kitchen")

        // when creating initial tag
        try realm.write {
            try cmd.apply(inRealm: realm)
        }

        // it gets stored with all properties
        let tag = try XCTUnwrap(realm.object(ofType: Tag.self, forPrimaryKey: "tag1"), "tag1 not found")
        XCTAssertEqual(tag.name, "kitchen")

        // 2. change the tag
        cmd.name = "kitchen..."
        // update object
        try realm.write {
            try cmd.apply(inRealm: realm)
        }
        // check status after update
        XCTAssertEqual(tag.name, "kitchen...")
    }

    func testApplyInRealm_dontOverwriteLastApplied() throws {
        // 1. initial tag
        var cmd = AddTagCommand(tagId: "tag1", name: "kitchen")

        // when creating initial tag
        try realm.write {
            try cmd.apply(inRealm: realm)
        }

        // it gets stored with all properties
        let tag = try XCTUnwrap(realm.object(ofType: Tag.self, forPrimaryKey: "tag1"), "tag1 not found")
        XCTAssertEqual(tag.name, "kitchen")

        // 2. set lastApplied
        try realm.write {
            tag.lastApplied = 1000
        }

        // 3. update the firebase tag
        cmd.name = "kitchen..."
        // update object
        try realm.write {
            try cmd.apply(inRealm: realm)
        }
        // check status after update
        XCTAssertEqual(tag.name, "kitchen...")
        XCTAssertEqual(tag.lastApplied, 1000)
    }
}
