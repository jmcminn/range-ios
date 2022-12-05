

import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `DeleteUploadCommand` in local Realm db
final class DeleteUploadCommandRealmTest: XCTestCase {
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
        let command = DeleteUploadCommand(uploadId: "upload1")
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.uploadNotFound)
        }
    }

    func testApply_successful() throws {
        let upload = Upload(
            id: "upload1",
            timestamp: Date(),
            name: nil,
            description: nil,
            correlationId: "upload1",
            fileType: .image,
            imageHeightToWidth: 1
        )
        try realm.write {
            realm.add(upload)
        }
        let command = DeleteUploadCommand(uploadId: "upload1")
        try realm.write {
            try command.apply(inRealm: realm)
        }

        XCTAssertTrue(upload.isInvalidated)
        XCTAssertNil(realm.object(ofType: Upload.self, forPrimaryKey: "upload1"))
    }
}

/// Tests applying `DeleteUploadCommand` to Firestore
final class DeleteUploadCommandFirestoreTest: XCTestCase {
    func testApply_noOp_noComment() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        let command = DeleteUploadCommand(uploadId: "upload1")
        XCTAssertEqual(context.operations.count, 0)
    }

    func testApply_successful() throws {
        let context = TestFirestoreCommandContext(docs: [.upload("upload1")])

        let command = DeleteUploadCommand(uploadId: "upload1")

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 1)
        AssertOperationsEqual(
            context.operations[0],
            .delete(.upload("upload1"))
        )
    }
}
