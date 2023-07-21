import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateNoteCompletedCommand` in local Realm db
final class UpdateNoteCompletedCommandRealmTest: ProjectModelTestCase {
    func testApply_noNote() throws {
        let command = UpdateNoteCompletedCommand(noteId: "comment1")
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.commentNotFound)
        }
    }

    func testApply_uncomplete_successful() throws {
        let user1 = Participant(id: "user1", firstName: "", lastName: "", avatarUrl: nil, email: "")
        let comment1 = Comment(
            id: "comment1",
            timestamp: Date(),
            text: "",
            textIsEdited: false,
            isNote: false,
            completedTimestamp: Date()
        )
        try realm.write {
            realm.add([user1, comment1])
            comment1.completedBy = user1
        }
        let command = UpdateNoteCompletedCommand(noteId: "comment1")
        try realm.write {
            try command.apply(inRealm: realm)
        }
        XCTAssertNil(comment1.completedBy)
        XCTAssertNil(comment1.completedTimestamp)
    }

    func testApply_complete_successful() throws {
        let user1 = Participant(id: "user1", firstName: "", lastName: "", avatarUrl: nil, email: "")
        let comment1 = Comment(
            id: "comment1",
            timestamp: Date(),
            text: "",
            textIsEdited: false,
            isNote: false,
            completedTimestamp: nil
        )
        try realm.write {
            realm.add([user1, comment1])
        }
        let command = UpdateNoteCompletedCommand(noteId: "comment1", completedById: "user1")
        try realm.write {
            try command.apply(inRealm: realm)
        }
        XCTAssertEqual(comment1.completedBy, user1)
        XCTAssertNil(comment1.completedTimestamp)
    }
}

/// Tests applying `UpdateNoteCompletedCommand` to Firestore
final class UpdateNoteCompletedCommandFirestoreTest: XCTestCase {
    func testApply_noUpload() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        let command = UpdateNoteCompletedCommand(noteId: "comment1")
        XCTAssertThrowsError(
            try command.apply(inFirestore: context)
        ) { error in
            guard case .obsolete("comment doesn't exist") = error as? FirestoreCommandError else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    func testApply_uncomplete_successful() throws {
        let context = TestFirestoreCommandContext(docs: [.comment("comment1")])

        let command = UpdateNoteCompletedCommand(noteId: "comment1")

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 1)
        AssertOperationsEqual(
            context.operations[0],
            .update(.comment("comment1"), [
                "completedBy": FieldValue.delete(),
                "completedTimestamp": FieldValue.delete(),
            ])
        )
    }

    func testApply_complete_successful() throws {
        let context = TestFirestoreCommandContext(docs: [
            .comment("comment1"),
            .participant("user1"),
        ])

        let command = UpdateNoteCompletedCommand(noteId: "comment1", completedById: "user1")

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 1)
        AssertOperationsEqual(
            context.operations[0],
            .update(.comment("comment1"), [
                "completedBy": "user1",
                "completedTimestamp": FieldValue.serverTimestamp(),
            ])
        )
    }
}
