import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateCollaborationNameCommand` in local Realm db
final class UpdateCollaborationNameCommandRealmTest: ProjectModelTestCase {
    func testApply_noCollaboration() throws {
        let command = UpdateCollaborationNameCommand(
            collaborationId: "collaboration1",
            name: "new name"
        )
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.collaborationNotFound)
        }
    }

    func testApply_successful() throws {
        let collaboration1 = Collaboration(id: "collaboration1", timestamp: Date(), name: "old name", description: nil)
        // setup collaboration1 with tag1 and tag2
        try realm.write {
            realm.add(collaboration1)
        }
        let command = UpdateCollaborationNameCommand(
            collaborationId: "collaboration1",
            name: "new name"
        )
        try realm.write {
            try command.apply(inRealm: realm)
        }

        XCTAssertEqual(collaboration1.name, "new name")
    }
}

/// Tests getting the parameters for `UpdateCollaborationNameCommand`Firebase function call
final class UpdateCollaborationCommandNameFirebaseFunctionTest: XCTestCase {
    let command = UpdateCollaborationNameCommand(
        collaborationId: "collaboration1",
        name: "new name"
    )

    func test_functionName() throws {
        XCTAssertEqual(command.functionName, "updateCollaboration")
    }

    func test_functionData() throws {
        let data = command.functionData("project1") as? [String: Any?]
        let expected: [String: Any?] = [
            "projectId": "project1",
            "collaborationId": "collaboration1",
            "name": "new name",
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
}
