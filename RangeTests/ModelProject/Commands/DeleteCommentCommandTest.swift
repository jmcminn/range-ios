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

/// Tests getting the parameters for `DeleteCommentCommand`Firebase function call
final class DeleteCommentCommandFirebaseFunctionTest: XCTestCase {
    func test_functionName() throws {
        let command = DeleteCommentCommand(commentId: "comment1")
        XCTAssertEqual(command.functionName, "deleteComment")
    }

    func test_functionData() throws {
        let command = DeleteCommentCommand(commentId: "comment1")
        let data = command.functionData("project1") as? [String: Any?]
        let expected: [String: Any?] = ["projectId": "project1", "commentId": "comment1"]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
}
