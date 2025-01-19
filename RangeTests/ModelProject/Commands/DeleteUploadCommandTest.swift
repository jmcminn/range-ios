

import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `DeleteUploadCommand` in local Realm db
final class DeleteUploadCommandRealmTest: ProjectModelTestCase {
    func testApply_noUpload() throws {
        let upload = Upload(placeholderId: "upload1")
        try realm.write {
            realm.add(upload)
        }
        let command = DeleteUploadCommand(uploadId: "upload2")
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
        let command = DeleteUploadCommand(uploadId: "upload1")
        try realm.write {
            try command.apply(inRealm: realm)
        }

        XCTAssertTrue(upload1.isInvalidated)
        XCTAssertNil(realm.object(ofType: Upload.self, forPrimaryKey: "upload1"))
        XCTAssertFalse(upload2.isInvalidated)
        XCTAssertNotNil(realm.object(ofType: Upload.self, forPrimaryKey: "upload2"))
    }
}

/// Tests getting the parameters for `DeleteUploadCommand`Firebase function call
final class DeleteUploadCommandFirebaseFunctionTest: XCTestCase {
    func test_functionName() throws {
        let command = DeleteUploadCommand(uploadId: "upload1")
        XCTAssertEqual(command.functionName, "deleteUpload")
    }

    func test_functionData() throws {
        let command = DeleteUploadCommand(uploadId: "upload1")
        let data = command.functionData
        let expected: [String: Any?] = ["uploadId": "upload1"]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
}
