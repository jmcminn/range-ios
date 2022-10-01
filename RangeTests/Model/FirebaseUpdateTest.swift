@testable import Range
import XCTest

class FirebaseUpdateRealmSyncTest: XCTestCase {
    func testDecode_unsupportedValueType() {
        let inputString = """
        {
            "parent": "13083d62-03a1-43d7-8eb0-ca5bb8b357f3",
            "parentType": "Collaboration",
            "timestamp": 1649228400000,
            "user": "9e06df97-aa0f-4e0f-8c78-8892bfb126ec",
            "field": "name",
            "oldValue": 1.23
        }
        """
        guard let inputData = inputString.data(using: .utf8) else {
            XCTFail("no input data"); return
        }
        XCTAssertThrowsError(
            try JSONDecoder().decode(FirebaseUpdate.self, from: inputData)
        ) { error in
            guard let error = error as? IntOrString.IntOrStringError, case .missingValue = error else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    // Tests if firebase object creates a proper upsert command
    func testUpsertCommand() throws {
        let firebaseUpdate = FirebaseUpdate(
            parentId: "collaboration1",
            parentType: "Collaboration",
            timestamp: 1000,
            userId: "user1",
            field: "name",
            oldValue: nil,
            newValue: .string("new name")
        )
        XCTAssertEqual(
            try firebaseUpdate.upsertCommand(id: "update1") as? AddUpdateCommand,
            AddUpdateCommand(
                updateId: "update1",
                parentId: "collaboration1",
                parentType: "Collaboration",
                timestamp: 1,
                userId: "user1",
                field: .name,
                oldValue: nil,
                newValue: .string("new name")
            )
        )
    }

    func testUpsertCommand_wrongParentType() throws {
        let firebaseUpdate = FirebaseUpdate(
            parentId: "feature1",
            parentType: "Feature",
            timestamp: 1000,
            userId: "user1",
            field: "name"
        )
        XCTAssertThrowsError(
            try firebaseUpdate.upsertCommand(id: "update1")
        ) { error in
            XCTAssertEqual(error.localizedDescription, "parentType not supported: Feature")
        }
    }

    func testUpsertCommand_unsupportedField() throws {
        let firebaseUpdate = FirebaseUpdate(
            parentId: "collaboration1",
            parentType: "Collaboration",
            timestamp: 1000,
            userId: "user1",
            field: "length"
        )
        XCTAssertThrowsError(
            try firebaseUpdate.upsertCommand(id: "update1")
        ) { error in
            XCTAssertEqual(error.localizedDescription, "length field not supported")
        }
    }
}
