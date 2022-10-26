@testable import Range
import XCTest

class FirebaseUploadRealmSyncTest: XCTestCase {
    // Tests if firebase object creates a proper upsert command
    func testUpsertCommand() throws {
        let firebaseUpload = FirebaseUpload(
            parentId: "collaboration1",
            parentType: "Collaboration",
            authorId: "user1",
            timestamp: 1000,
            name: "name",
            uploadDescription: "description",
            correlationId: "upload1",
            tagIds: ["tag1"]
        )
        XCTAssertEqual(
            try firebaseUpload.upsertCommand(id: "upload1") as? AddUploadCommand,
            AddUploadCommand(
                uploadId: "upload1",
                correlationId: "upload1",
                fileType: .image,
                parentType: "Collaboration",
                parentId: "collaboration1",
                authorId: "user1",
                timestamp: 1,
                name: "name",
                uploadDescription: "description",
                tagIds: ["tag1"]
            )
        )
    }

    func testUpsertCommand_wrongParentType() throws {
        let firebaseUpload = FirebaseUpload(
            parentId: "feature1",
            parentType: "Feature",
            authorId: "user1",
            timestamp: 1000,
            name: "name",
            uploadDescription: "description",
            correlationId: "upload1",
            tagIds: ["tag1"]
        )
        XCTAssertThrowsError(
            try firebaseUpload.upsertCommand(id: "upload1")
        ) { error in
            XCTAssertEqual(error.localizedDescription, "parentType not supported: Feature")
        }
    }
}
