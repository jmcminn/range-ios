@testable import Range
import XCTest

class FirebaseTagNameTest: XCTestCase {
    // Tests if firebase object creates a proper upsert command
    func testUpsertCommand() throws {
        let firebaseTagName = FirebaseTagName(name: "kitchen")
        XCTAssertEqual(
            try firebaseTagName.upsertCommand(id: "tag1") as? AddTagCommand,
            AddTagCommand(tagId: "tag1", name: "kitchen")
        )
    }
}
