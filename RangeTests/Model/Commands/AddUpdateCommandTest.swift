import CoreLocation
@testable import Range
import RealmSwift
import Turf
import XCTest

class AddUpdateCommandTest: XCTestCase {
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

    // Adds a parent and author placeholders if not found
    func testApplyInRealm_createPlaceholders() throws {
        let cmd = AddUpdateCommand(
            updateId: "udpate1",
            parentId: "collaboration1",
            parentType: "Collaboration",
            timestamp: Date.now,
            userId: "user2",
            field: .name
        )
        try realm.write {
            try cmd.apply(inRealm: realm)
        }
        let collaboration = try XCTUnwrap(
            realm.object(ofType: Collaboration.self, forPrimaryKey: "collaboration1"),
            "collaboration1 not found"
        )
        XCTAssertTrue(collaboration.placeholder)
        let author = try XCTUnwrap(
            realm.object(ofType: Participant.self, forPrimaryKey: "user2"),
            "user2 not found"
        )
        XCTAssertTrue(author.placeholder)
    }

    func testAddUpdateToCollaboration_successful() throws {
        // 1. create 2 collaborations and a user
        let user1 = Participant(
            id: "user1",
            firstName: "First",
            lastName: "Last",
            avatarUrl: nil,
            email: "first@last.com"
        )
        let collaboration1 = Collaboration(
            id: "collaboration1",
            timestamp: Date.now,
            name: "Collaboration1",
            description: ""
        )
        let collaboration2 = Collaboration(
            id: "collaboration2",
            timestamp: Date.now,
            name: "Collaboration2",
            description: ""
        )
        try realm.write {
            realm.add([user1, collaboration1, collaboration2])
        }
        XCTAssertEqual(collaboration1.uploads.count, 0)
        XCTAssertEqual(collaboration2.uploads.count, 0)

        // 2. add update to collaboration1
        let cmd1 = AddUpdateCommand(
            updateId: "update1",
            parentId: "collaboration1",
            parentType: "Collaboration",
            timestamp: Date(timeIntervalSince1970: 1),
            userId: "user1",
            field: .name,
            oldValue: nil,
            newValue: .string("after")
        )
        try realm.write {
            try cmd1.apply(inRealm: realm)
        }
        XCTAssertEqual(collaboration1.updates.count, 1)
        XCTAssertEqual(collaboration2.updates.count, 0)
        let update1 = try XCTUnwrap(realm.object(ofType: Update.self, forPrimaryKey: "update1"), "update1 not found")
        XCTAssertEqual(update1.timestamp.timeIntervalSince1970, 1)
        XCTAssertEqual(update1.user, user1)
        XCTAssertEqual(update1.field, Update.Field.name)
        XCTAssertEqual(update1.oldValue, .none)
        XCTAssertEqual(update1.newValue, .string("after"))

        // 4. add another update to collaboration1
        let cmd2 = AddUpdateCommand(
            updateId: "update2",
            parentId: "collaboration1",
            parentType: "Collaboration",
            timestamp: Date.now,
            userId: "user1",
            field: .name,
            oldValue: .string("before"),
            newValue: nil
        )
        try realm.write {
            try cmd2.apply(inRealm: realm)
        }
        XCTAssertEqual(collaboration1.updates.count, 2)
        XCTAssertEqual(collaboration2.updates.count, 0)
        let update2 = try XCTUnwrap(realm.object(ofType: Update.self, forPrimaryKey: "update2"), "update2 not found")
        XCTAssertEqual(update2.field, Update.Field.name)
        XCTAssertEqual(update2.oldValue, .string("before"))
        XCTAssertEqual(update2.newValue, .none)
    }
}
