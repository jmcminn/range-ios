import CoreLocation
@testable import Range
import RealmSwift
import Turf
import XCTest

class AddCommentCommandTest: XCTestCase {
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
        let cmd = AddCommentCommand(
            commentId: "comment1",
            parentType: "Collaboration",
            parentId: "collaboration1",
            authorId: "user2",
            timestamp: 1,
            text: "",
            isCompleted: nil
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

    func testApplyInRealm_successful() throws {
        // 1. create 2 collaborations and a user
        let user1 = Participant(
            id: "user1",
            firstName: "First",
            lastName: "Last",
            avatarUrl: nil,
            email: "first@last.com"
        )
        let collaboration1 = Collaboration(id: "collaboration1", name: "Collaboration1", description: "")
        let collaboration2 = Collaboration(id: "collaboration2", name: "Collaboration2", description: "")
        try realm.write {
            realm.add([user1, collaboration1, collaboration2])
        }
        XCTAssertEqual(collaboration1.comments.count, 0)
        XCTAssertEqual(collaboration2.comments.count, 0)

        // 2. add comment to collaboration1
        var cmd1 = AddCommentCommand(
            commentId: "comment1",
            parentType: "Collaboration",
            parentId: "collaboration1",
            authorId: "user1",
            timestamp: 1,
            text: "comment 1",
            isCompleted: nil
        )
        try realm.write {
            try cmd1.apply(inRealm: realm)
        }
        XCTAssertEqual(collaboration1.comments.count, 1)
        XCTAssertEqual(collaboration2.comments.count, 0)
        let comment1 = try XCTUnwrap(
            realm.object(ofType: Comment.self, forPrimaryKey: "comment1"),
            "comment1 not found"
        )
        XCTAssertEqual(comment1.text, "comment 1")
        XCTAssertEqual(comment1.author, user1)
        XCTAssertEqual(comment1.timestamp, 1)

        // 3. update comment1
        cmd1.text = "comment 1 ..."
        try realm.write {
            try cmd1.apply(inRealm: realm)
        }
        XCTAssertEqual(collaboration1.comments.count, 1)
        XCTAssertEqual(collaboration2.comments.count, 0)
        XCTAssertEqual(comment1.text, "comment 1 ...")

        // 4. add another comment to collaboration1
        let cmd2 = AddCommentCommand(
            commentId: "comment2",
            parentType: "Collaboration",
            parentId: "collaboration1",
            authorId: "user1",
            timestamp: 2,
            text: "comment 2",
            isCompleted: nil
        )
        try realm.write {
            try cmd2.apply(inRealm: realm)
        }
        XCTAssertEqual(collaboration1.comments.count, 2)
        XCTAssertEqual(collaboration2.comments.count, 0)

        // 5. remove comment2
        try realm.write {
            let comment2 = try XCTUnwrap(
                realm.object(ofType: Comment.self, forPrimaryKey: "comment2"),
                "comment2 not found"
            )
            realm.delete(comment2)
        }
        XCTAssertEqual(collaboration1.comments.count, 1)
        XCTAssertEqual(collaboration2.comments.count, 0)
        XCTAssertEqual(collaboration1.comments.first, comment1)
    }
}
