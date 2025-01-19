import CoreLocation
import FirebaseFirestore
@testable import Range
import RealmSwift
import Turf
import XCTest

/// Tests applying `CreateCommentCommand` in local Realm db
final class CreateCommentCommandRealmTest: ProjectModelTestCase {
    let collaborationCommentCommand = CreateCommentCommand.collaborationComment(
        collaborationId: "collaboration1",
        authorId: "user1",
        text: "comment\ntext",
        isNote: true
    )

    let uploadCommentCommand = CreateCommentCommand.uploadComment(
        uploadId: "upload1",
        authorId: "user1",
        text: "comment\ntext"
    )

    func testApply_noCollaboration() throws {
        let user1 = Participant(placeholderId: "user1")
        try realm.write {
            realm.add(user1)
            XCTAssertThrowsError(
                try collaborationCommentCommand.apply(inRealm: realm)
            ) { error in
                XCTAssertEqual(error as! ModelError, ModelError.collaborationNotFound)
            }
        }
    }

    func testApply_noUpload() throws {
        let user1 = Participant(placeholderId: "user1")
        try realm.write {
            realm.add(user1)
            XCTAssertThrowsError(
                try uploadCommentCommand.apply(inRealm: realm)
            ) { error in
                XCTAssertEqual(error as! ModelError, ModelError.uploadNotFound)
            }
        }
    }

    func testApply_noUser() throws {
        let collaboration1 = Collaboration(
            id: "collaboration1",
            createdAt: Date(),
            lastUpdatedAt: Date(),
            name: "old name",
            description: nil
        )
        try realm.write {
            realm.add(collaboration1)
        }
        XCTAssertThrowsError(
            try collaborationCommentCommand.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.userNotFound)
        }
    }

    func testApply_collaborationComment_successful() throws {
        let commentId = collaborationCommentCommand.commentId
        let collaboration1 = Collaboration(
            id: "collaboration1",
            createdAt: Date(),
            lastUpdatedAt: Date(),
            name: "old name",
            description: nil
        )
        let user1 = Participant(placeholderId: "user1")
        try realm.write {
            realm.add([collaboration1, user1])
        }
        try realm.write {
            try collaborationCommentCommand.apply(inRealm: realm)
        }
        let comment1 = try XCTUnwrap(realm.object(ofType: Comment.self, forPrimaryKey: commentId))
        XCTAssertEqual(comment1.author, user1)
        XCTAssertEqual(comment1.text, "comment\ntext")
        XCTAssertEqual(comment1.textIsEdited, false)
        XCTAssertEqual(comment1.isNote, true)
        XCTAssertEqual(collaboration1.comments.map(\.id), [commentId])
    }

    func testApply_uploadComment_successful() throws {
        let commentId = uploadCommentCommand.commentId
        let upload1 = Upload(id: "upload1", createdAt: Date(), lastUpdatedAt: Date(), name: nil, description: nil,
                             correlationId: "upload1", fileType: .jpeg, imageHeightToWidth: nil, fileSize: 1024)
        let user1 = Participant(placeholderId: "user1")
        try realm.write {
            realm.add([upload1, user1])
        }
        try realm.write {
            try uploadCommentCommand.apply(inRealm: realm)
        }
        let comment1 = try XCTUnwrap(realm.object(ofType: Comment.self, forPrimaryKey: commentId))
        XCTAssertEqual(comment1.author, user1)
        XCTAssertEqual(comment1.text, "comment\ntext")
        XCTAssertEqual(comment1.textIsEdited, false)
        XCTAssertEqual(comment1.isNote, false)
        XCTAssertEqual(upload1.comments.map(\.id), [commentId])
    }
}

/// Tests getting the parameters for the Firebase function call
final class CreateCommentCommandFirebaseFunctionTest: XCTestCase {
    func test_functionName() throws {
        let command = CreateCommentCommand.uploadComment(uploadId: "upload1", authorId: "user1", text: "text")
        XCTAssertEqual(command.functionName, "createComment")
    }

    func test_functionData_uploadComment() throws {
        let command = CreateCommentCommand.uploadComment(uploadId: "upload1", authorId: "user1", text: "text")
        let data = command.functionData
        let expected: [String: Any?] = [
            "commentId": command.commentId,
            "parentType": "Upload",
            "parentId": "upload1",
            "text": "text",
            "isNote": false,
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }

    func test_functionData_collaborationComment() throws {
        let command = CreateCommentCommand.collaborationComment(
            collaborationId: "collaboration1",
            authorId: "user1",
            text: "text",
            isNote: true
        )
        let data = command.functionData
        let expected: [String: Any?] = [
            "commentId": command.commentId,
            "parentType": "Collaboration",
            "parentId": "collaboration1",
            "text": "text",
            "isNote": true,
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
}
