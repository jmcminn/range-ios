import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateUploadTagsCommand` in local Realm db
final class UpdateUploadTagsCommandRealmTest: XCTestCase {
    let pendingUploadsModel = TestPendingUploadsModel()
    let pendingActionsModel = TestPendingActionsModel()
    var model: ProjectModel!
    var realm: Realm!

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
        let command = UpdateUploadTagsCommand(uploadId: "upload1", tags: [])
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.uploadNotFound)
        }
    }

    func testApply_successful() throws {
        let upload1 = Upload(
            id: "upload1",
            timestamp: Date(),
            name: "upload 1",
            description: nil,
            correlationId: "upload1",
            fileType: .jpeg,
            imageHeightToWidth: 1,
            fileSize: 1024
        )
        let tag1 = Tag(id: "tag1", name: "tag 1")
        let tag2 = Tag(id: "tag2", name: "tag 2")
        // setup upload1 with tag1 and tag2
        try realm.write {
            realm.add([upload1, tag1, tag2])
            upload1.tags.append(objectsIn: [tag1, tag2])
            tag1.uploads.insert(upload1)
            tag2.uploads.insert(upload1)
        }
        // update to tag2, tag3
        let command = UpdateUploadTagsCommand(
            uploadId: "upload1",
            tags: [
                .init(id: "tag2", name: "tag 2"),
                .init(id: "tag3", name: "tag 3"),
            ]
        )
        try realm.write {
            try command.apply(inRealm: realm)
        }

        let tag3 = try XCTUnwrap(realm.object(ofType: Tag.self, forPrimaryKey: "tag3"), "tag3 not found")
        XCTAssertEqual(tag3.name, "tag 3")
        XCTAssertTrue(tag1.uploads.isEmpty)
        for tag in [tag2, tag3] {
            XCTAssertEqual(tag.uploads.map(\.id), ["upload1"])
        }
        XCTAssertEqual(upload1.tags.map(\.id), ["tag2", "tag3"])
    }
}

/// Tests applying `UpdateUploadTagsCommand` to Firestore
final class UpdateUploadTagsCommandFirestoreTest: XCTestCase {
    func testApply_noUpload() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        let command = UpdateUploadTagsCommand(uploadId: "upload1", tags: [])
        XCTAssertThrowsError(
            try command.apply(inFirestore: context)
        ) { error in
            guard case .obsolete("upload doesn't exist") = error as? FirestoreCommandError else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    func testApply_successful() throws {
        // upload exists
        // there's also tag1 and tag2 already in firestore
        let context = TestFirestoreCommandContext(docs: [
            .upload("upload1"),
            .tagName("tag1"), .tagName("tag2"),
        ])

        let command = UpdateUploadTagsCommand(
            uploadId: "upload1",
            tags: [
                .init(id: "tag2", name: "tag 2"),
                .init(id: "tag3", name: "tag 3"),
            ]
        )
        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 2)
        AssertOperationsEqual(
            context.operations[0],
            .set(.tagName("tag3"), ["name": "tag 3"])
        )
        AssertOperationsEqual(
            context.operations[1],
            .update(.upload("upload1"), ["tags": ["tag2", "tag3"]])
        )
    }

    /// Test for idempotency
    /// All objects already exist, meaning this operation was already run
    func testApply_noOp() throws {
        // upload exists
        // there's also tag1 and tag2 already in firestore
        let context = TestFirestoreCommandContext(docs: [
            .upload("upload1"),
            .tagName("tag1"), .tagName("tag2"), .tagName("tag3"),
        ])

        let command = UpdateUploadTagsCommand(
            uploadId: "upload1",
            tags: [
                .init(id: "tag2", name: "tag 2"),
                .init(id: "tag3", name: "tag 3"),
            ]
        )
        try command.apply(inFirestore: context)

        // the update to upload tags is still perfomed as updating tags multiple times to same value
        // is ok
        XCTAssertEqual(context.operations.count, 1)
        AssertOperationsEqual(
            context.operations[0],
            .update(.upload("upload1"), ["tags": ["tag2", "tag3"]])
        )
    }
}
