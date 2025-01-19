import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateCollaborationStatusCommand` in local Realm db
final class UpdateCollaborationStatusCommandRealmTest: ProjectModelTestCase {
    func testApply_noCollaboration() throws {
        let command = UpdateCollaborationStatusCommand(
            collaborationId: "collaboration1",
            statusId: "status1"
        )
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.collaborationNotFound)
        }
    }

    func testApply_noStatus() throws {
        let collaboration1 = Collaboration(
            id: "collaboration1",
            createdAt: Date(),
            lastUpdatedAt: Date(),
            name: "old name",
            description: nil
        )
        // setup collaboration
        try realm.write {
            realm.add(collaboration1)
        }
        let command = UpdateCollaborationStatusCommand(
            collaborationId: "collaboration1",
            statusId: "status1"
        )
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.statusNotFound)
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
        let status1 = Status(id: "status1", name: "Status 1", hexColor: "#123456", isInitial: false, isCompleted: false)
        // setup collaboration and status
        try realm.write {
            realm.add([collaboration1, status1])
        }
        let command = UpdateCollaborationStatusCommand(
            collaborationId: "collaboration1",
            statusId: "status1"
        )
        try realm.write {
            try command.apply(inRealm: realm)
        }

        XCTAssertEqual(collaboration1.status, status1)
    }
}

/// Tests getting the parameters for the Firebase function call
final class UpdateCollaborationStatusCommandFirebaseFunctionTest: XCTestCase {
    let command = UpdateCollaborationStatusCommand(
        collaborationId: "collaboration1",
        statusId: "status1"
    )

    func test_functionName() throws {
        XCTAssertEqual(command.functionName, "updateCollaboration")
    }

    func test_functionData() throws {
        let data = command.functionData
        let expected: [String: Any?] = [
            "collaborationId": "collaboration1",
            "statusId": "status1",
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
}
