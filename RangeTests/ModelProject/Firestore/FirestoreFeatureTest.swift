import CoreLocation
@testable import Range
import RealmSwift
import Turf
import XCTest

class FirestoreFeatureTest: ProjectModelTestCase {
    // MARK: - upsert tests

    // Adds a geometry placeholder if not found
    func testUpsert_geometryNotFound() throws {
        let firestoreFeature = FirestoreFeature(
            geometryId: "geometry1",
            name: "name",
            description: "description"
        )
        try realm.write {
            try firestoreFeature.upsert(withId: "feature1", inRealm: realm)
        }
        let geometry = try XCTUnwrap(
            realm.object(ofType: Geometry.self, forPrimaryKey: "geometry1"),
            "geometry1 not found"
        )
        XCTAssertTrue(geometry.placeholder)
    }

    func testUpsert_successful() throws {
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
        var firestoreFeature1 = FirestoreFeature(
            geometryId: "geometry1",
            name: "Feature1",
            description: ""
        )
        try realm.write {
            try firestoreFeature1.upsert(withId: "feature1", inRealm: realm)
        }
        XCTAssertEqual(geometry1.features.count, 1)
        XCTAssertEqual(geometry2.features.count, 0)
        let feature1 = try XCTUnwrap(
            realm.object(ofType: Feature.self, forPrimaryKey: "feature1"),
            "feature1 not found"
        )
        XCTAssertEqual(feature1.name, "Feature1")
        XCTAssertEqual(feature1.geometry.first, geometry1)

        // 3. update feature1
        firestoreFeature1.name = "Feature1..."
        try realm.write {
            try firestoreFeature1.upsert(withId: "feature1", inRealm: realm)
        }
        XCTAssertEqual(geometry1.features.count, 1)
        XCTAssertEqual(geometry2.features.count, 0)
        XCTAssertEqual(feature1.name, "Feature1...")

        // 4. add another feature to geometry1
        let firestoreFeature2 = FirestoreFeature(
            geometryId: "geometry1",
            name: "Feature2",
            description: ""
        )
        try realm.write {
            try firestoreFeature2.upsert(withId: "feature2", inRealm: realm)
        }
        XCTAssertEqual(geometry1.features.count, 2)
        XCTAssertEqual(geometry2.features.count, 0)

        // 5. remove feature2
        try realm.write {
            let feature2 = try XCTUnwrap(
                realm.object(ofType: Feature.self, forPrimaryKey: "feature2"),
                "feature2 not found"
            )
            realm.delete(feature2)
        }
        XCTAssertEqual(geometry1.features.count, 1)
        XCTAssertEqual(geometry2.features.count, 0)
        XCTAssertEqual(geometry1.features.first, feature1)
    }
}
