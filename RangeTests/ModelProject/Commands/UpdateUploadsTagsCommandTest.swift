import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateUploadTagsCommand` in local Realm db
final class UpdateUploadTagsCommandRealmTest: ProjectModelTestCase {
    func testApply_noUpload() throws {
        let upload1 = Upload(placeholderId: "upload1")
        try realm.write {
            realm.add(upload1)
        }
        let command = UpdateUploadTagsCommand(uploadId: "upload2", tags: [])
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.uploadNotFound)
        }
    }

    func testApply_successful() throws {
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

/// Tests getting the parameters for the Firebase function call
final class UpdateUploadTagsCommandFirebaseFunctionTest: XCTestCase {
    func test_functionName() throws {
        let command = UpdateUploadTagsCommand(
            uploadId: "upload1",
            tags: [.init(id: "tag1", name: "tag 1")]
        )
        XCTAssertEqual(command.functionName, "updateUpload")
    }

    func test_functionData() throws {
        let command = UpdateUploadTagsCommand(
            uploadId: "upload1",
            tags: [.init(id: "tag1", name: "tag 1"),
                   .init(id: "tag2", name: "tag 2")]
        )
        let data = command.functionData
        let expected: [String: Any?] = [
            "uploadId": "upload1",
            "tags": [
                ["id": "tag1", "name": "tag 1"],
                ["id": "tag2", "name": "tag 2"],
            ],
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
}
