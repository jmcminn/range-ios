import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateUploadDescriptionCommand` in local Realm db
final class UpdateUploadDescriptionCommandRealmTest: XCTestCase {
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
        let command = UpdateUploadDescriptionCommand(
            authorId: "user1",
            uploadId: "upload1",
            uploadDescription: "new description"
        )
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
            name: nil,
            description: "description",
            correlationId: "upload1",
            fileType: .jpeg,
            imageHeightToWidth: nil,
            fileSize: 1024
        )
        // setup collaboration1 with tag1 and tag2
        try realm.write {
            realm.add(upload1)
        }
        let command = UpdateUploadDescriptionCommand(
            authorId: "user1",
            uploadId: "upload1",
            uploadDescription: "new description"
        )
        try realm.write {
            try command.apply(inRealm: realm)
        }

        XCTAssertEqual(upload1.uploadDescription, "new description")
    }
}

/// Tests applying `UpdateUploadDescriptionCommand` to Firestore
final class UpdateUploadDescriptionCommandFirestoreTest: XCTestCase {
    func testApply_noUpload() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        let command = UpdateUploadDescriptionCommand(
            authorId: "user1",
            uploadId: "upload1",
            uploadDescription: "new description"
        )
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
        let context = TestFirestoreCommandContext(docs: [], docsData: [
            .upload("upload1"): FirestoreUpload(
                parentId: "collaboration1",
                parentType: "Collaboration",
                authorId: "user1",
                timestamp: Timestamp(),
                correlationId: "upload1",
                tagIds: []
            ),
        ])

        let command = UpdateUploadDescriptionCommand(
            authorId: "user1",
            uploadId: "upload1",
            uploadDescription: "new description"
        )
        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 1)
        AssertOperationsEqual(
            context.operations[0],
            .update(.upload("upload1"), ["description": "new description"])
        )
    }

    /// Test for idempotency
    /// The description is the same as in Firestore... ignore
    func testApply_noOp_descriptionUnchanged() throws {
        // upload exists
        let context = TestFirestoreCommandContext(docs: [], docsData: [
            .upload("upload1"): FirestoreUpload(
                parentId: "collaboration1",
                parentType: "Collaboration",
                authorId: "user1",
                timestamp: Timestamp(),
                uploadDescription: "description",
                correlationId: "upload1",
                tagIds: []
            ),
        ])
        // same description
        let command = UpdateUploadDescriptionCommand(
            authorId: "user1",
            uploadId: "upload1",
            uploadDescription: "description"
        )
        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 0)
    }
}
