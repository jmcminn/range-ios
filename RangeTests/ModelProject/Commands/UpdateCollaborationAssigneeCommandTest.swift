import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateCollaborationAssigneeCommand` in local Realm db
final class UpdateCollaborationAssigneeCommandRealmTest: ProjectModelTestCase {
    func testApply_noCollaboration() throws {
        let command = UpdateCollaborationAssigneeCommand(
            collaborationId: "collaboration1",
            assigneeId: nil
        )
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.collaborationNotFound)
        }
    }

    func testApply_noUser() throws {
        let collaboration1 = Collaboration(
            id: "collaboration1",
            createdAt: Date(),
            lastUpdatedAt: Date(),
            name: "old name",
            description: nil
        )
        // setup collaboration1
        try realm.write {
            realm.add(collaboration1)
        }
        let command = UpdateCollaborationAssigneeCommand(
            collaborationId: "collaboration1",
            assigneeId: "user2"
        )

        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.userNotFound)
        }
    }

    func testApply_successful() throws {
        let collaboration1 = Collaboration(
            id: "collaboration1",
            createdAt: Date(),
            lastUpdatedAt: Date(),
            name: "old name",
            description: nil
        )
        let user2 = Participant(placeholderId: "user2")
        // setup collaboration1
        try realm.write {
            realm.add([collaboration1, user2])
        }
        let command = UpdateCollaborationAssigneeCommand(
            collaborationId: "collaboration1",
            assigneeId: "user2"
        )
        try realm.write {
            try command.apply(inRealm: realm)
        }

        XCTAssertEqual(collaboration1.assignee, user2)
    }
}

/// Tests getting the parameters for Firebase function call
final class UpdateCollaborationAssigneeCommandFirebaseFunctionTest: XCTestCase {
    func test_functionName() throws {
        let command = UpdateCollaborationAssigneeCommand(
            collaborationId: "collaboration1",
            assigneeId: "user2"
        )
        XCTAssertEqual(command.functionName, "updateCollaboration")
    }

    func test_functionData() throws {
        let command = UpdateCollaborationAssigneeCommand(
            collaborationId: "collaboration1",
            assigneeId: "user2"
        )
        let data = command.functionData
        let expected: [String: Any?] = [
            "collaborationId": "collaboration1",
            "assigneeId": "user2",
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }

    func test_functionData_unset() throws {
        let command = UpdateCollaborationAssigneeCommand(
            collaborationId: "collaboration1",
            assigneeId: nil
        )
        let data = command.functionData
        let expected: [String: Any?] = [
            "collaborationId": "collaboration1",
            "assigneeId": nil,
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
}
