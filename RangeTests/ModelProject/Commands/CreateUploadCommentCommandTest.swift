import CoreLocation
import FirebaseFirestore
@testable import Range
import RealmSwift
import Turf
import XCTest

/// Tests applying `CreateUploadCommentCommand` in local Realm db
final class CreateUploadCommentCommandRealmTest: XCTestCase {
    let pendingUploadsModel = TestPendingUploadsModel()
    let pendingActionsModel = TestPendingActionsModel()
    var model: ProjectModel!
    var realm: Realm!

    let command = CreateUploadCommentCommand(
        commentId: "comment1",
        uploadId: "upload1",
        authorId: "user1",
        text: "comment\ntext"
    )

    @MainActor
    override func setUpWithError() throws {
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(
            userId: "user1",
            projectId: UUID().uuidString,
            imageCaches: ImageCaches(),
            pendingUploadsModel: pendingUploadsModel,
            pendingActionsModel: pendingActionsModel,
            inMemory: true
        )
        realm = model.mainRealm
    }

    func testApply_noUpload() throws {
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.uploadNotFound)
        }
    }

    func testApply_noUser() throws {
        let upload1 = Upload(id: "upload1", timestamp: Date(), name: nil, description: nil,
                             correlationId: "upload1", fileType: .jpeg, imageHeightToWidth: nil, fileSize: 1024)
        try realm.write {
            realm.add(upload1)
        }
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.userNotFound)
        }
    }

    func testApply_successful() throws {
        let upload1 = Upload(id: "upload1", timestamp: Date(), name: nil, description: nil,
                             correlationId: "upload1", fileType: .jpeg, imageHeightToWidth: nil, fileSize: 1024)
        let user1 = Participant(id: "user1", firstName: "", lastName: "", avatarUrl: nil, email: "")
        try realm.write {
            realm.add([upload1, user1])
        }
        try realm.write {
            try command.apply(inRealm: realm)
        }
        let comment1 = try XCTUnwrap(realm.object(ofType: Comment.self, forPrimaryKey: "comment1"))
        XCTAssertEqual(comment1.author, user1)
        XCTAssertEqual(comment1.text, "comment\ntext")
        XCTAssertEqual(comment1.textIsEdited, false)
        XCTAssertEqual(comment1.isNote, false)
        XCTAssertEqual(upload1.comments.map(\.id), ["comment1"])
    }
}

/// Tests applying `CreateUploadCommentCommand` in to Firestore (using a mock for FirestoreCommandContext)
final class CreateUploadCommentCommandFirestoreTest: XCTestCase {
    let command = CreateUploadCommentCommand(
        commentId: "comment1",
        uploadId: "upload1",
        authorId: "user1",
        text: "comment\ntext"
    )

    func testApply_noUpload() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        XCTAssertThrowsError(
            try command.apply(inFirestore: context)
        ) { error in
            guard case .obsolete("upload doesn't exist") = error as? FirestoreCommandError else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    func testApply_noUser() throws {
        // upload exists but user doesn't
        let context = TestFirestoreCommandContext(docs: [.upload("upload1")])

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
            .upload("upload1"),
            .participant("user1"),
            .tagName("tag1"),
        ])

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 1)
        AssertOperationsEqual(
            context.operations[0],
            .set(.comment("comment1"), [
                "parent": "upload1",
                "parentType": "Upload",
                "author": "user1",
                "timestamp": FieldValue.serverTimestamp(),
                "text": "comment\ntext",
                "textIsEdited": false,
                "isNote": false,
            ])
        )
    }

    /// Test for idempotency
    /// All objects already exist, meaning this operation was already run
    func testApply_noOp() throws {
        // all objects exist
        let context = TestFirestoreCommandContext(docs: [
            .upload("upload1"),
            .participant("user1"),
            .comment("comment1"),
        ])

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 0)
    }
}
