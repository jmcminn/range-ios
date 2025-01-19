import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateCommentTextCommand` in local Realm db
final class UpdateCommentTextCommandRealmTest: ProjectModelTestCase {
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
            createdAt: Date(), lastUpdatedAt: Date(),
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

/// Tests getting the parameters for Firebase function call
final class UpdateCommentTextCommandNameFirebaseFunctionTest: XCTestCase {
    let command = UpdateCommentTextCommand(commentId: "comment1", text: "text")

    func test_functionName() throws {
        XCTAssertEqual(command.functionName, "updateComment")
    }

    func test_functionData() throws {
        let data = command.functionData
        let expected: [String: Any?] = [
            "commentId": "comment1",
            "text": "text",
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
}
