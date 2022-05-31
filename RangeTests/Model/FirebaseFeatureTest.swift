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
    func testAddFeatureToGeometry_successful() throws {
        // 1. create 2 geometries with no features
        let geometry1 = Geometry(
            id: "geometry1",
            annotationType: .photoMarker,
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        )
        let geometry2 = Geometry(
            id: "geometry2",
            annotationType: .photoMarker,
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 33.5, longitude: -96.5)))
        )
        try realm.write {
            realm.add([geometry1, geometry2])
        }
        XCTAssertEqual(geometry1.features.count, 0)
        XCTAssertEqual(geometry2.features.count, 0)

        // 2. add feature to geometry1
        var firebaseFeature1 = FirebaseFeature(id: "feature1", geometryId: "geometry1", name: "Feature1")
        try realm.write {
            try firebaseFeature1.upsert(realm)
        }
        XCTAssertEqual(geometry1.features.count, 1)
        XCTAssertEqual(geometry2.features.count, 0)
        guard let feature1 = realm.object(ofType: Feature.self, forPrimaryKey: "feature1") else {
            throw "feature1 not found"
        }
        XCTAssertEqual(feature1.name, "Feature1")
        XCTAssertEqual(feature1.geometry.first, geometry1)
//
        // 3. update feature1
        firebaseFeature1.name = "Feature1..."
        try realm.write {
            try firebaseFeature1.upsert(realm)
        }
        XCTAssertEqual(geometry1.features.count, 1)
        XCTAssertEqual(geometry2.features.count, 0)
        XCTAssertEqual(feature1.name, "Feature1...")

        // 4. add another feature to geometry1
        let firebaseFeature2 = FirebaseFeature(id: "feature2", geometryId: "geometry1", name: "Feature2")
        try realm.write {
            try firebaseFeature2.upsert(realm)
        }
        XCTAssertEqual(geometry1.features.count, 2)
        XCTAssertEqual(geometry2.features.count, 0)

        // 5. remove feature2
        try realm.write {
            guard let feature2 = realm.object(ofType: Feature.self, forPrimaryKey: "feature2") else {
                throw "feature2 not found"
            }
            realm.delete(feature2)
        }
        XCTAssertEqual(geometry1.features.count, 1)
        XCTAssertEqual(geometry2.features.count, 0)
        XCTAssertEqual(geometry1.features.first, feature1)
    }
}
