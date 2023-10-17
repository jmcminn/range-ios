import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `AddUploadsToCollaborationCommand` in local Realm db
final class AddUploadsToCollaborationCommandRealmTest: ProjectModelTestCase {
    let command = AddUploadsToCollaborationCommand(
        authorId: "user1",
        collaborationId: "collaboration1",
        tags: [.init(id: "tag1", name: "tag 1"), .init(id: "tag2", name: "tag 2")],
        uploadDescription: "upload description",
        uploads: [
            .init(id: "upload1", fileType: .jpeg, fileSize: 1024, imageHeightToWidth: 1.0),
            .init(id: "upload2", fileType: .jpeg, fileSize: 1024, imageHeightToWidth: 2.0),
        ],
        mediaKeys: []
    )

    func testApply_noCollaboration() throws {
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.collaborationNotFound)
        }
    }

    func testApply_noUser() throws {
        let collaboration1 = Collaboration(
            id: "collaboration1",
            timestamp: Date.now,
            name: "Collaboration1",
            description: ""
        )
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
        let user1 = Participant(placeholderId: "user1")
        let collaboration1 = Collaboration(
            id: "collaboration1",
            timestamp: Date.now,
            name: "Collaboration1",
            description: ""
        )
        try realm.write {
            realm.add([user1, collaboration1])
        }
        try realm.write {
            try command.apply(inRealm: realm)
        }

        let tag1 = try XCTUnwrap(realm.object(ofType: Tag.self, forPrimaryKey: "tag1"), "tag1 not found")
        XCTAssertEqual(tag1.name, "tag 1")
        let tag2 = try XCTUnwrap(realm.object(ofType: Tag.self, forPrimaryKey: "tag2"), "tag2 not found")
        XCTAssertEqual(tag2.name, "tag 2")
        let upload1 = try XCTUnwrap(realm.object(ofType: Upload.self, forPrimaryKey: "upload1"), "upload1 not found")
        let upload2 = try XCTUnwrap(realm.object(ofType: Upload.self, forPrimaryKey: "upload2"), "upload2 not found")
        for upload in [upload1, upload2] {
            XCTAssertEqual(upload.author, user1)
            XCTAssertNil(upload.name)
            XCTAssertEqual(upload.uploadDescription, "upload description")
            XCTAssertEqual(upload.collaboration.first, collaboration1)
            XCTAssertEqual(upload.correlationId, upload.id)
            XCTAssertEqual(upload.fileType, .jpeg)
            XCTAssertEqual(upload.tags.map(\.id), ["tag1", "tag2"])
        }
        XCTAssertEqual(upload1.imageHeightToWidth, 1)
        XCTAssertEqual(upload2.imageHeightToWidth, 2)
        for tag in [tag1, tag2] {
            XCTAssertEqual(tag.uploads.map(\.id), ["upload1", "upload2"])
        }
        XCTAssertEqual(collaboration1.uploads.map(\.id), ["upload1", "upload2"])
    }
}

/// Tests applying `AddUploadsToCollaborationCommand` in to Firestore (using a mock for FirestoreCommandContext)
final class AddUploadsToCollaborationCommandFirestoreTest: XCTestCase {
    let command = AddUploadsToCollaborationCommand(
        authorId: "user1",
        collaborationId: "collaboration1",
        tags: [.init(id: "tag1", name: "tag 1"), .init(id: "tag2", name: "tag 2")],
        uploadDescription: "upload description",
        uploads: [
            .init(id: "upload1", fileType: .jpeg, fileSize: 1024, imageHeightToWidth: 1.0),
            .init(id: "upload2", fileType: .jpeg, fileSize: 1024, imageHeightToWidth: 2.0),
        ],
        mediaKeys: []
    )

    func testApply_noCollaboration() throws {
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
        // collaboration and user exist
        // there's also tag1 already in firestore
        let context = TestFirestoreCommandContext(docs: [
            .collaboration("collaboration1"),
            .participant("user1"),
            .tagName("tag1"),
        ])

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 3)
        AssertOperationsEqual(
            context.operations[0],
            .set(.tagName("tag2"), ["name": "tag 2"])
        )
        AssertOperationsEqual(
            context.operations[1],
            .set(.upload("upload1"), [
                "parent": "collaboration1", "parentType": "Collaboration",
                "correlation": "upload1", "author": "user1", "timestamp": FieldValue.serverTimestamp(),
                "tags": ["tag1", "tag2"], "description": "upload description",
                "fileType": "jpeg", "imageHeightToWidth": 1.0, "fileSize": 1024,
            ])
        )
        AssertOperationsEqual(
            context.operations[2],
            .set(.upload("upload2"), [
                "parent": "collaboration1", "parentType": "Collaboration",
                "correlation": "upload2", "author": "user1", "timestamp": FieldValue.serverTimestamp(),
                "tags": ["tag1", "tag2"], "description": "upload description",
                "fileType": "jpeg", "imageHeightToWidth": 2.0, "fileSize": 1024,
            ])
        )
    }

    /// Test for idempotency
    /// All objects already exist, meaning this operation was already run
    func testApply_noOp() throws {
        // collaboration and user exist
        let context = TestFirestoreCommandContext(docs: [
            .collaboration("collaboration1"),
            .participant("user1"),
            .tagName("tag1"), .tagName("tag2"),
            .upload("upload1"), .upload("upload2"),
        ])

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 0)
    }
}
