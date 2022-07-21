@testable import Range
import XCTest

class FirebaseStatusNameTest: XCTestCase {
    // Tests if firebase object creates a proper upsert command
    func testUpsertCommand() throws {
        let firebaseStatus = FirebaseStatusName(
            name: "In progress",
            color: "#123456",
            isInitial: true,
            isCompleted: false
        )
        XCTAssertEqual(
            try firebaseStatus.upsertCommand(id: "status1") as? AddStatusCommand,
            AddStatusCommand(
                statusId: "status1",
                name: "In progress",
                color: "#123456",
                isInitial: true,
                isCompleted: false
            )
        )
    }
}
