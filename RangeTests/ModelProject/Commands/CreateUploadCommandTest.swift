import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `CreateUploadCommand` in local Realm db
final class CreateUploadCommandRealmTest: ProjectModelTestCase {
    var command: CreateUploadCommand {
        CreateUploadCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            tags: [.init(id: "tag1", name: "tag 1"), .init(id: "tag2", name: "tag 2")],
            uploadDescription: "upload description",
            upload: .init(mediaKey: _mediaKey(uploadId: "upload1"), fileSize: 1024, imageHeightToWidth: 1.0)
        )
    }

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
        let upload = try XCTUnwrap(realm.object(ofType: Upload.self, forPrimaryKey: "upload1"), "upload1 not found")
        XCTAssertEqual(upload.author, user1)
        XCTAssertNil(upload.name)
        XCTAssertEqual(upload.uploadDescription, "upload description")
        XCTAssertEqual(upload.collaboration.first, collaboration1)
        XCTAssertEqual(upload.correlationId, upload.id)
        XCTAssertEqual(upload.fileType, .jpeg)
        XCTAssertEqual(upload.tags.map(\.id), ["tag1", "tag2"])
        XCTAssertEqual(upload.imageHeightToWidth, 1)
        for tag in [tag1, tag2] {
            XCTAssertEqual(tag.uploads.map(\.id), ["upload1"])
        }
        XCTAssertEqual(collaboration1.uploads.map(\.id), ["upload1"])
    }
}

/// Tests getting the parameters for the Firebase function call
final class CreateUploadCommandFirebaseFunctionTest: ProjectModelTestCase {
    func test_functionName() throws {
        let command = CreateUploadCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            tags: [.init(id: "tag1", name: "tag 1"), .init(id: "tag2", name: "tag 2")],
            uploadDescription: "upload description",
            upload: CommandUpload(mediaKey: _mediaKey(uploadId: "upload1"), fileSize: 1024, imageHeightToWidth: 1.0)
        )
        XCTAssertEqual(command.functionName, "createUpload")
    }

    func test_functionData() throws {
        let command = CreateUploadCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            tags: [.init(id: "tag1", name: "tag 1"), .init(id: "tag2", name: "tag 2")],
            uploadDescription: "upload description",
            upload: CommandUpload(mediaKey: _mediaKey(uploadId: "upload1"), fileSize: 1024, imageHeightToWidth: 1.0)
        )
        let data = command.functionData("project1") as? [String: Any?]
        let expected: [String: Any?] = [
            "projectId": "project1",
            "collaborationId": "collaboration1",
            "uploadId": "upload1",
            "fileType": "jpeg",
            "fileSize": 1024,
            "imageHeightToWidth": 1,
            "correlationId": "upload1",
            "name": nil,
            "description": "upload description",
            "tags": [
                ["id": "tag1", "name": "tag 1"],
                ["id": "tag2", "name": "tag 2"],
            ],
            "annotations": nil,
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }

    func test_functionData_pdf() throws {
        let command = CreateUploadCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            tags: [],
            uploadDescription: nil,
            upload: CommandUpload(
                mediaKey: MediaKey(projectId: model.projectId, uploadId: "upload1",
                                   fileType: .pdf, annotated: false, storageVersion: "1",
                                   storeInDiskCache: false, isFromLocalFiles: false),
                fileSize: 1024, imageHeightToWidth: nil
            )
        )
        let data = command.functionData("project1") as? [String: Any?]
        let expected: [String: Any?] = [
            "projectId": "project1",
            "collaborationId": "collaboration1",
            "uploadId": "upload1",
            "fileType": "pdf",
            "fileSize": 1024,
            "imageHeightToWidth": nil,
            "correlationId": "upload1",
            "name": nil,
            "description": nil,
            "tags": [],
            "annotations": nil,
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
}
