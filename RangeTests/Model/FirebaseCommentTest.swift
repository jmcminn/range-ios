import FirebaseFirestore
@testable import Range
import XCTest

class FirebaseCommentRealmSyncTest: XCTestCase {
    // Tests if firebase object creates a proper upsert command and fills in the defaults for optionals
    func testUpsertCommand_defaultValues() throws {
        let firebaseComment = FirebaseComment(
            parentId: "collaboration1",
            parentType: "Collaboration",
            authorId: "user1",
            timestamp: Timestamp(date: Date(timeIntervalSince1970: 1)),
            text: "comment 1"
        )
        XCTAssertEqual(
            try firebaseComment.upsertCommand(id: "comment1") as? UpsertCommentCommand,
            UpsertCommentCommand(
                commentId: "comment1",
                parentType: "Collaboration",
                parentId: "collaboration1",
                authorId: "user1",
                timestamp: Date(timeIntervalSince1970: 1),
                text: "comment 1",
                textIsEdited: false,
                isNote: false,
                completedById: nil,
                completedTimestamp: nil
            )
        )
    }

    // Tests if firebase object creates a proper upsert command
    func testUpsertCommand() throws {
        let firebaseComment = FirebaseComment(
            parentId: "collaboration1",
            parentType: "Collaboration",
            authorId: "user1",
            timestamp: Timestamp(date: Date(timeIntervalSince1970: 1)),
            text: "comment 1",
            textIsEdited: true,
            isNote: true,
            completedById: "user2",
            completedTimestamp: Timestamp(date: Date(timeIntervalSince1970: 2))
        )
        XCTAssertEqual(
            try firebaseComment.upsertCommand(id: "comment1") as? UpsertCommentCommand,
            UpsertCommentCommand(
                commentId: "comment1",
                parentType: "Collaboration",
                parentId: "collaboration1",
                authorId: "user1",
                timestamp: Date(timeIntervalSince1970: 1),
                text: "comment 1",
                textIsEdited: true,
                isNote: true,
                completedById: "user2",
                completedTimestamp: Date(timeIntervalSince1970: 2)
            )
        )
    }

    func testUpsertCommand_wrongParentType() throws {
        let firebaseComment = FirebaseComment(
            parentId: "feature1",
            parentType: "Feature",
            authorId: "user1",
            timestamp: Timestamp(),
            text: "comment 1"
        )
        XCTAssertThrowsError(
            try firebaseComment.upsertCommand(id: "comment1")
        ) { error in
            XCTAssertEqual(error.localizedDescription, "parentType not supported: Feature")
        }
    }
}
