

import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `DeleteUploadsCommand` in local Realm db
final class DeleteUploadsCommandRealmTest: ProjectModelTestCase {
    func testApply_noUpload() throws {
        let upload = Upload(placeholderId: "upload1")
        try realm.write {
            realm.add(upload)
        }
        let command = DeleteUploadsCommand(uploadIds: ["upload1", "upload2"])
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.uploadNotFound)
        }
    }

    func testApply_successful() throws {
        let upload1 = Upload(placeholderId: "upload1")
        let upload2 = Upload(placeholderId: "upload2")
        try realm.write {
            realm.add([upload1, upload2])
        }
        let command = DeleteUploadsCommand(uploadIds: ["upload1", "upload2"])
        try realm.write {
            try command.apply(inRealm: realm)
        }

        XCTAssertTrue(upload1.isInvalidated)
        XCTAssertNil(realm.object(ofType: Upload.self, forPrimaryKey: "upload1"))
        XCTAssertTrue(upload2.isInvalidated)
        XCTAssertNil(realm.object(ofType: Upload.self, forPrimaryKey: "upload2"))
    }
}

/// Tests applying `DeleteUploadsCommand` to Firestore
final class DeleteUploadsCommandFirestoreTest: XCTestCase {
    func testApply_noOp_noComment() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        let command = DeleteUploadsCommand(uploadIds: ["upload1"])
        try command.apply(inFirestore: context)
        XCTAssertEqual(context.operations.count, 0)
    }

    func testApply_successful() throws {
        let context = TestFirestoreCommandContext(docs: [.upload("upload1")])

        let command = DeleteUploadsCommand(uploadIds: ["upload1"])

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 1)
        AssertOperationsEqual(
            context.operations[0],
            .delete(.upload("upload1"))
        )
    }

    func testApply_successful_multipleUploadIds() throws {
        let context = TestFirestoreCommandContext(docs: [.upload("upload1"), .upload("upload3")])

        let command = DeleteUploadsCommand(uploadIds: ["upload1", "upload2", "upload3"])

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 2, "only existing uploads are deleted")
        AssertOperationsEqual(context.operations[0], .delete(.upload("upload1")))
        AssertOperationsEqual(context.operations[1], .delete(.upload("upload3")))
    }
}
