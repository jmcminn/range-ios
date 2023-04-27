import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateUploadsTagsCommand` in local Realm db
final class UpdateUploadsTagsCommandRealmTest: XCTestCase {
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
            localFiles: LocalFiles(),
            pendingUploadsModel: pendingUploadsModel,
            pendingActionsModel: pendingActionsModel,
            inMemory: true
        )
        realm = model.mainRealm
    }

    func testApply_noUpload() throws {
        let upload1 = Upload(placeholderId: "upload1")
        try realm.write {
            realm.add(upload1)
        }
        let command = UpdateUploadsTagsCommand(uploadIds: ["upload1", "upload2"], tags: [])
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.uploadNotFound)
        }
    }

    func testApply_successful() throws {
        let upload1 = Upload(placeholderId: "upload1")
        let upload2 = Upload(placeholderId: "upload2")
        let tag1 = Tag(id: "tag1", name: "tag 1")
        let tag2 = Tag(id: "tag2", name: "tag 2")
        // setup upload1 with tag1 and tag2 and upload2 with no tags
        try realm.write {
            realm.add([upload1, upload2, tag1, tag2])
            upload1.tags.append(objectsIn: [tag1, tag2])
            tag1.uploads.insert(upload1)
            tag2.uploads.insert(upload1)
        }
        // update to tag2, tag3
        let command = UpdateUploadsTagsCommand(
            uploadIds: ["upload1", "upload2"],
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
            XCTAssertEqual(tag.uploads.map(\.id), ["upload1", "upload2"])
        }
        XCTAssertEqual(upload1.tags.map(\.id), ["tag2", "tag3"])
        XCTAssertEqual(upload2.tags.map(\.id), ["tag2", "tag3"])
    }

    /// Test that new tags are added but not duplicated (not added if already there)
    func testApply_add() throws {
        let upload1 = Upload(placeholderId: "upload1")
        let tag1 = Tag(id: "tag1", name: "tag 1")
        let tag2 = Tag(id: "tag2", name: "tag 2")
        // setup upload1 with tag1 and tag2
        try realm.write {
            realm.add([upload1, tag1, tag2])
            upload1.tags.append(objectsIn: [tag1, tag2])
            tag1.uploads.insert(upload1)
            tag2.uploads.insert(upload1)
        }
        // add tag2, tag3
        let command = UpdateUploadsTagsCommand(
            uploadIds: ["upload1"],
            tags: [
                .init(id: "tag2", name: "tag 2"),
                .init(id: "tag3", name: "tag 3"),
            ],
            add: true // add instead of replace
        )
        try realm.write {
            try command.apply(inRealm: realm)
        }

        let tag3 = try XCTUnwrap(realm.object(ofType: Tag.self, forPrimaryKey: "tag3"), "tag3 not found")
        XCTAssertEqual(tag3.name, "tag 3")
        for tag in [tag1, tag2, tag3] {
            XCTAssertEqual(tag.uploads.map(\.id), ["upload1"])
        }
        XCTAssertEqual(upload1.tags.map(\.id), ["tag1", "tag2", "tag3"])
    }
}

/// Tests applying `UpdateUploadsTagsCommand` to Firestore
final class UpdateUploadsTagsCommandFirestoreTest: XCTestCase {
    func testApply_noUpload() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        let command = UpdateUploadsTagsCommand(uploadIds: ["upload1"], tags: [])
        XCTAssertThrowsError(
            try command.apply(inFirestore: context)
        ) { error in
            guard case .obsolete("upload doesn't exist") = error as? FirestoreCommandError else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    func testApply_successful() throws {
        // upload 1 and 2 exist, upload3 doesn't exist
        // there's also tag1 and tag2 already in firestore
        let context = TestFirestoreCommandContext(docs: [
            .tagName("tag1"), .tagName("tag2"),
        ], docsData: [
            .upload("upload1"): FirestoreUpload(
                parentId: "c1", parentType: "Collaboration", authorId: "user1", timestamp: Timestamp(),
                correlationId: "upload1", tagIds: ["tag1", "tag2"]
            ),
            .upload("upload2"): FirestoreUpload(
                parentId: "c1", parentType: "Collaboration", authorId: "user1", timestamp: Timestamp(),
                correlationId: "upload2", tagIds: []
            ),
        ])

        let command = UpdateUploadsTagsCommand(
            uploadIds: ["upload1", "upload2", "upload3"],
            tags: [
                .init(id: "tag2", name: "tag 2"),
                .init(id: "tag3", name: "tag 3"),
            ]
        )
        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 3)
        AssertOperationsEqual(
            context.operations[0],
            .set(.tagName("tag3"), ["name": "tag 3"])
        )
        AssertOperationsEqual(
            context.operations[1],
            .update(.upload("upload1"), ["tags": ["tag2", "tag3"]])
        )
        AssertOperationsEqual(
            context.operations[2],
            .update(.upload("upload2"), ["tags": ["tag2", "tag3"]])
        )
    }

    /// Test for idempotency
    /// All objects already exist, meaning this operation was already run
    func testApply_noOp() throws {
        // upload exists
        // there's also tag1 and tag2 already in firestore
        let context = TestFirestoreCommandContext(docs: [
            .tagName("tag1"), .tagName("tag2"), .tagName("tag3"),
        ], docsData: [.upload("upload1"): FirestoreUpload(
            parentId: "c1", parentType: "Collaboration", authorId: "user1", timestamp: Timestamp(),
            correlationId: "uploads", tagIds: ["tag1", "tag2"]
        )])

        let command = UpdateUploadsTagsCommand(
            uploadIds: ["upload1"],
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

    /// Test that new tags are added but not duplicated (not added if already there)
    func testApply_add() throws {
        // upload 1 with tag1 and tag2 already in firestore
        let context = TestFirestoreCommandContext(docs: [
            .tagName("tag1"), .tagName("tag2"),
        ], docsData: [
            .upload("upload1"): FirestoreUpload(
                parentId: "c1", parentType: "Collaboration", authorId: "user1", timestamp: Timestamp(),
                correlationId: "uploads", tagIds: ["tag1", "tag2"]
            ),
        ])

        let command = UpdateUploadsTagsCommand(
            uploadIds: ["upload1"],
            tags: [
                .init(id: "tag2", name: "tag 2"),
                .init(id: "tag3", name: "tag 3"),
            ],
            add: true
        )
        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 2)
        AssertOperationsEqual(
            context.operations[0],
            .set(.tagName("tag3"), ["name": "tag 3"])
        )
        AssertOperationsEqual(
            context.operations[1],
            .update(.upload("upload1"), ["tags": ["tag1", "tag2", "tag3"]])
        )
    }
}
