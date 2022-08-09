@testable import Range
import XCTest

class FirebaseCommentRealmSyncTest: XCTestCase {
    // Tests if firebase object creates a proper upsert command
    func testUpsertCommand() throws {
        let firebaseComment = FirebaseComment(
            parentId: "collaboration1",
            parentType: "Collaboration",
            authorId: "user1",
            timestamp: 1000,
            text: "comment 1",
            isCompleted: nil
        )
        XCTAssertEqual(
            try firebaseComment.upsertCommand(id: "comment1") as? AddCommentCommand,
            AddCommentCommand(
                commentId: "comment1",
                parentType: "Collaboration",
                parentId: "collaboration1",
                authorId: "user1",
                timestamp: 1,
                text: "comment 1",
                isCompleted: nil
            )
        )
    }

    func testUpsertCommand_wrongParentType() throws {
        let firebaseComment = FirebaseComment(
            parentId: "feature1",
            parentType: "Feature",
            authorId: "user1",
            timestamp: 1,
            text: "comment 1",
            isCompleted: nil
        )
        XCTAssertThrowsError(
            try firebaseComment.upsertCommand(id: "comment1")
        ) { error in
            XCTAssertEqual(error.localizedDescription, "parentType not supported: Feature")
        }
    }
}
