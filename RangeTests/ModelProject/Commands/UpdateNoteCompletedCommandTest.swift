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
        let user1 = Participant(placeholderId: "user1")
        let comment1 = Comment(
            id: "comment1",
            createdAt: Date(), lastUpdatedAt: Date(),
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
        let user1 = Participant(placeholderId: "user1")
        let comment1 = Comment(
            id: "comment1",
            createdAt: Date(), lastUpdatedAt: Date(),
            text: "",
            textIsEdited: false,
            isNote: false,
            completedTimestamp: nil
        )
        try realm.write {
            realm.add([user1, comment1])
        }
        let command = UpdateNoteCompletedCommand(noteId: "comment1", completedById: "user1", completedTimestamp: Date())
        try realm.write {
            try command.apply(inRealm: realm)
        }
        XCTAssertEqual(comment1.completedBy, user1)
        XCTAssertNotNil(comment1.completedTimestamp)
    }
}

/// Tests getting the parameters for Firebase function call
final class UpdateNoteCompletedCommandFirebaseFunctionTest: XCTestCase {
    func test_complete() throws {
        let completedTimestamp = Date()
        let command = UpdateNoteCompletedCommand(
            noteId: "comment1",
            completedById: "user1",
            completedTimestamp: completedTimestamp
        )
        XCTAssertEqual(command.functionName, "updateComment")

        let data = command.functionData("project1") as? [String: Any?]
        let expected: [String: Any?] = [
            "projectId": "project1",
            "commentId": "comment1",
            "completedTimestamp": Int(completedTimestamp.timeIntervalSince1970 * 1000),
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }

    func test_uncomplete() throws {
        let command = UpdateNoteCompletedCommand(noteId: "comment1")
        XCTAssertEqual(command.functionName, "updateComment")

        let data = command.functionData("project1") as? [String: Any?]
        let expected: [String: Any?] = [
            "projectId": "project1",
            "commentId": "comment1",
            "completedTimestamp": nil,
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
}
