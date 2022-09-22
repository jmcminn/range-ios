@testable import Range
import XCTest

class FirebaseCollaborationTest: XCTestCase {
    // Tests if firebase object creates a proper upsert command
    func testUpsertCommand() throws {
        let firebaseCollaboration = FirebaseCollaboration(
            featureId: "feature1",
            authorId: "user1",
            timestamp: 1000,
            statusId: "status1",
            name: "Collaboration1",
            collaborationDescription: "",
            tagIds: []
        )
        XCTAssertEqual(
            try firebaseCollaboration.upsertCommand(id: "collaboration1") as? AddCollaborationCommand,
            AddCollaborationCommand(
                collaborationId: "collaboration1",
                featureId: "feature1",
                authorId: "user1",
                timestamp: 1.0,
                name: "Collaboration1",
                collaborationDescription: "",
                statusId: "status1",
                tagIds: []
            )
        )
    }
}
