import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateCollaborationDueDateCommand` in local Realm db
final class UpdateCollaborationDueDateCommandRealmTest: ProjectModelTestCase {
    func testApply_noCollaboration() throws {
        let command = UpdateCollaborationDueDateCommand(
            collaborationId: "collaboration1",
            dueDateTimestamp: nil
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
        let command = UpdateCollaborationDueDateCommand(
            collaborationId: "collaboration1",
            dueDateTimestamp: Date(timeIntervalSince1970: 100)
        )
        try realm.write {
            try command.apply(inRealm: realm)
        }

        XCTAssertEqual(collaboration1.dueDateTimestamp?.timeIntervalSince1970, 100)
    }
}

/// Tests getting the parameters for `UpdateCollaborationDueDateCommand`Firebase function call
final class UpdateCollaborationDueDateCommandFirebaseFunctionTest: XCTestCase {
    func test_functionName() throws {
        let command = UpdateCollaborationDueDateCommand(
            collaborationId: "collaboration1",
            dueDateTimestamp: Date(timeIntervalSince1970: 100)
        )
        XCTAssertEqual(command.functionName, "updateCollaboration")
    }

    func test_functionData() throws {
        let command = UpdateCollaborationDueDateCommand(
            collaborationId: "collaboration1",
            dueDateTimestamp: Date(timeIntervalSince1970: 100)
        )
        let data = command.functionData("project1") as? [String: Any?]
        let expected: [String: Any?] = [
            "projectId": "project1",
            "collaborationId": "collaboration1",
            "dueDateTimestamp": 100_000,
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }

    func test_functionData_unset() throws {
        let command = UpdateCollaborationDueDateCommand(
            collaborationId: "collaboration1",
            dueDateTimestamp: nil
        )
        let data = command.functionData("project1") as? [String: Any?]
        let expected: [String: Any?] = [
            "projectId": "project1",
            "collaborationId": "collaboration1",
            "dueDateTimestamp": nil,
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
}
