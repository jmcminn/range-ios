import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateCommentTextCommand` in local Realm db
final class UpdateCommentTextCommandRealmTest: XCTestCase {
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

    func testApply_noComment() throws {
        let command = UpdateCommentTextCommand(commentId: "comment1", text: "text")
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.commentNotFound)
        }
    }

    func testApply_successful() throws {
        let comment1 = Comment(
            id: "comment1",
            timestamp: Date(),
            text: "",
            textIsEdited: false,
            isNote: false,
            completedTimestamp: Date()
        )
        try realm.write {
            realm.add(comment1)
        }
        let command = UpdateCommentTextCommand(commentId: "comment1", text: "text")
        try realm.write {
            try command.apply(inRealm: realm)
        }

        XCTAssertEqual(comment1.text, "text")
        XCTAssertFalse(comment1.textIsEdited)
    }
}

/// Tests applying `UpdateCommentTextCommand` to Firestore
final class UpdateCommentTextCommandFirestoreTest: XCTestCase {
    func testApply_noComment() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        let command = UpdateCommentTextCommand(commentId: "comment1", text: "text")
        XCTAssertThrowsError(
            try command.apply(inFirestore: context)
        ) { error in
            guard case .obsolete("comment doesn't exist") = error as? FirestoreCommandError else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    func testApply_successful() throws {
        let context = TestFirestoreCommandContext(docs: [], docsData: [
            .comment("comment1"): FirestoreComment(
                parentId: "collaboration1",
                parentType: "Collaboration",
                authorId: "user1",
                timestamp: Timestamp(),
                text: "something"
            ),
        ])

        let command = UpdateCommentTextCommand(commentId: "comment1", text: "text")

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 1)
        AssertOperationsEqual(
            context.operations[0],
            .update(.comment("comment1"), [
                "text": "text",
                "textIsEdited": true,
            ])
        )
    }

    /// Test for idempotency
    /// The text is the same as in Firestore... ignore
    func testApply_noOp_textUnchanged() throws {
        let context = TestFirestoreCommandContext(docs: [], docsData: [
            .comment("comment1"): FirestoreComment(
                parentId: "collaboration1",
                parentType: "Collaboration",
                authorId: "user1",
                timestamp: Timestamp(),
                text: "text"
            ),
        ])

        let command = UpdateCommentTextCommand(commentId: "comment1", text: "text")

        try command.apply(inFirestore: context)

        // the update of tags is still perfomed as updating tags multiple times to same value is ok
        XCTAssertEqual(context.operations.count, 0)
    }
}
