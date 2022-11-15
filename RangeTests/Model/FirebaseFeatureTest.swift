@testable import Range
import XCTest

class FirebaseFeatureTest: XCTestCase {
    // Tests if firebase object creates a proper upsert command
    func testUpsertCommand() throws {
        let firebaseFeature = FirebaseFeature(
            geometryId: "geometry1",
            name: "name",
            description: "description"
        )
        XCTAssertEqual(
            try firebaseFeature.upsertCommand(id: "feature1") as? UpsertFeatureCommand,
            UpsertFeatureCommand(
                featureId: "feature1",
                geometryId: "geometry1",
                name: "name",
                featureDescription: "description"
            )
        )
    }
}
