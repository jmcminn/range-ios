import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `DeleteCommentCommand` in local Realm db
final class DeleteCommentCommandRealmTest: ProjectModelTestCase {
    func testApply_noComment() throws {
        let command = DeleteCommentCommand(commentId: "comment1")
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.commentNotFound)
        }
    }

    func testApply_successful() throws {
        let comment1 = Comment(
            id: "comment1", timestamp: Date(), text: "",
            textIsEdited: false, isNote: false, completedTimestamp: nil
        )
        try realm.write {
            realm.add(comment1)
        }
        let command = DeleteCommentCommand(commentId: "comment1")
        try realm.write {
            try command.apply(inRealm: realm)
        }

        XCTAssertTrue(comment1.isInvalidated)
        XCTAssertNil(realm.object(ofType: Comment.self, forPrimaryKey: "comment1"))
    }
}

/// Tests applying `DeleteCommentCommand` to Firestore
final class DeleteCommentCommandFirestoreTest: XCTestCase {
    func testApply_noOp_noComment() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        let command = DeleteCommentCommand(commentId: "comment1")
        try command.apply(inFirestore: context)
        XCTAssertEqual(context.operations.count, 0)
    }

    func testApply_successful() throws {
        let context = TestFirestoreCommandContext(docs: [.comment("comment1")])

        let command = DeleteCommentCommand(commentId: "comment1")

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 1)
        AssertOperationsEqual(
            context.operations[0],
            .delete(.comment("comment1"))
        )
    }
}
