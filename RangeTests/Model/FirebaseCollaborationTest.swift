@testable import Range
import XCTest

class FirebaseCollaborationTest: XCTestCase {
    // Tests if firebase object creates a proper upsert command
    func testUpsertCommand() throws {
        let firebaseCollaboration = FirebaseCollaboration(
            featureId: "feature1",
            statusId: "status1",
            name: "Collaboration1",
            description: "",
            tagIds: []
        )
        XCTAssertEqual(
            try firebaseCollaboration.upsertCommand(id: "collaboration1") as? AddCollaborationCommand,
            AddCollaborationCommand(
                collaborationId: "collaboration1",
                featureId: "feature1",
                name: "Collaboration1",
                collaborationDescription: "",
                statusId: "status1",
                tagIds: []
            )
        )
    }
}
