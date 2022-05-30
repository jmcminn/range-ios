import CoreLocation
@testable import Range
import RealmSwift
import Turf
import XCTest

class FirebaseFeatureRealmSyncTest: XCTestCase {
    var model: ProjectModel!
    var realm: Realm!

    override func setUpWithError() throws {
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(projectId: UUID().uuidString, inMemory: true)
        realm = model.mainRealm
    }

    func testAddFeatureToGeometry_geometryNotFound() throws {
        let firebaseFeature = FirebaseFeature(id: "feature1", geometryId: "geometry1", name: "name")
        try realm.write {
            XCTAssertThrowsError(
                try firebaseFeature.upsert(realm)
            ) { error in
                XCTAssertEqual(error.localizedDescription, "geometry not found: geometry1")
            }
        }
    }

    // TODO: 38
    func testAddFeatureToGeometry_successful() throws {}
}
