import CoreLocation
import FirebaseFirestore
@testable import Range
import RealmSwift
import Turf
import XCTest

/// Tests applying `CreateCollaborationCommentCommand` in local Realm db
final class CreateCollaborationCommentCommandRealmTest: ProjectModelTestCase {
    let command = CreateCollaborationCommentCommand(
        commentId: "comment1",
        collaborationId: "collaboration1",
        authorId: "user1",
        text: "comment\ntext",
        isNote: true
    )

    func testApply_noCollaboration() throws {
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.collaborationNotFound)
        }
    }

    func testApply_noUser() throws {
        let collaboration1 = Collaboration(id: "collaboration1", timestamp: Date(), name: "old name", description: nil)
        try realm.write {
            realm.add(collaboration1)
        }
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.userNotFound)
        }
    }

    func testApply_successful() throws {
        let collaboration1 = Collaboration(id: "collaboration1", timestamp: Date(), name: "old name", description: nil)
        let user1 = Participant(id: "user1", firstName: "", lastName: "", avatarUrl: nil, email: "")
        try realm.write {
            realm.add([collaboration1, user1])
        }
        try realm.write {
            try command.apply(inRealm: realm)
        }
        let comment1 = try XCTUnwrap(realm.object(ofType: Comment.self, forPrimaryKey: "comment1"))
        XCTAssertEqual(comment1.author, user1)
        XCTAssertEqual(comment1.text, "comment\ntext")
        XCTAssertEqual(comment1.textIsEdited, false)
        XCTAssertEqual(comment1.isNote, true)
        XCTAssertEqual(collaboration1.comments.map(\.id), ["comment1"])
    }
}

/// Tests applying `CreateCollaborationCommentCommand` in to Firestore (using a mock for FirestoreCommandContext)
final class CreateCollaborationCommentCommandFirestoreTest: XCTestCase {
    let command = CreateCollaborationCommentCommand(
        commentId: "comment1",
        collaborationId: "collaboration1",
        authorId: "user1",
        text: "comment\ntext",
        isNote: true
    )

    func testApply_noCanvas() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        XCTAssertThrowsError(
            try command.apply(inFirestore: context)
        ) { error in
            guard case .obsolete("collaboration doesn't exist") = error as? FirestoreCommandError else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    func testApply_noUser() throws {
        // collaboration exists but user doesn't
        let context = TestFirestoreCommandContext(docs: [.collaboration("collaboration1")])

        XCTAssertThrowsError(
            try command.apply(inFirestore: context)
        ) { error in
            guard case .obsolete("user doesn't exist") = error as? FirestoreCommandError else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    func testApply_successful() throws {
        let context = TestFirestoreCommandContext(docs: [
            .collaboration("collaboration1"),
            .participant("user1"),
            .tagName("tag1"),
        ])

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 1)
        AssertOperationsEqual(
            context.operations[0],
            .set(.comment("comment1"), [
                "parent": "collaboration1",
                "parentType": "Collaboration",
                "author": "user1",
                "timestamp": FieldValue.serverTimestamp(),
                "text": "comment\ntext",
                "textIsEdited": false,
                "isNote": true,
            ])
        )
    }

    /// Test for idempotency
    /// All objects already exist, meaning this operation was already run
    func testApply_noOp() throws {
        // all objects exist
        let context = TestFirestoreCommandContext(docs: [
            .collaboration("collaboration1"),
            .participant("user1"),
            .comment("comment1"),
        ])

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 0)
    }
}
