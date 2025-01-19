import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateUploadDescriptionCommand` in local Realm db
final class UpdateUploadDescriptionCommandRealmTest: ProjectModelTestCase {
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
            createdAt: Date(), lastUpdatedAt: Date(),
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

/// Tests getting the parameters for Firebase function call
final class UpdateUploadDescriptionCommandFirebaseFunctionTest: XCTestCase {
    func testFunctionCommand() throws {
        let command = UpdateUploadDescriptionCommand(
            authorId: "user1",
            uploadId: "upload1",
            uploadDescription: "new description"
        )
        XCTAssertEqual(command.functionName, "updateUpload")

        let data = command.functionData
        let expected: [String: Any?] = [
            "uploadId": "upload1",
            "description": "new description"
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
}
