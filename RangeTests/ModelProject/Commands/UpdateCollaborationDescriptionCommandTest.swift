import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateCollaborationDescriptionCommand` in local Realm db
final class UpdateCollaborationDescriptionCommandRealmTest: ProjectModelTestCase {
    func testApply_noCollaboration() throws {
        let command = UpdateCollaborationDescriptionCommand(
            collaborationId: "collaboration1",
            description: "new description"
        )
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.collaborationNotFound)
        }
    }

    func testApply_successful() throws {
        let collaboration1 = Collaboration(
            id: "collaboration1",
            timestamp: Date(),
            name: "old name",
            description: "description"
        )
        // setup collaboration1 with tag1 and tag2
        try realm.write {
            realm.add(collaboration1)
        }
        let command = UpdateCollaborationDescriptionCommand(
            collaborationId: "collaboration1",
            description: "new description"
        )
        try realm.write {
            try command.apply(inRealm: realm)
        }

        XCTAssertEqual(collaboration1.collaborationDescription, "new description")
    }
}

/// Tests getting the parameters for `UpdateCollaborationDescriptionCommand`Firebase function call
final class UpdateCollaborationCommandDescriptionFirebaseFunctionTest: XCTestCase {
    let command = UpdateCollaborationDescriptionCommand(
        collaborationId: "collaboration1",
        description: "new description"
    )

    func test_functionName() throws {
        XCTAssertEqual(command.functionName, "updateCollaboration")
    }

    func test_functionData() throws {
        let data = command.functionData("project1") as? [String: Any?]
        let expected: [String: Any?] = [
            "projectId": "project1",
            "collaborationId": "collaboration1",
            "description": "new description",
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
}
