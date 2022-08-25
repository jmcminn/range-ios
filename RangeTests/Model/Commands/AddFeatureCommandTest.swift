import CoreLocation
@testable import Range
import RealmSwift
import Turf
import XCTest

class AddFeatureCommandTest: XCTestCase {
    var pendingUploadsModel: PendingUploadsModel!
    var model: ProjectModel!
    var realm: Realm!

    override func setUpWithError() throws {
        pendingUploadsModel = TestPendingUploadsModel()
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(
            userId: "user1",
            projectId: UUID().uuidString,
            imageCaches: ImageCaches(projectId: ""),
            pendingUploadsModel: pendingUploadsModel,
            inMemory: true
        )
        realm = model.mainRealm
    }

    // Adds a geometry placeholder if not found
    func testApplyInRealm_geometryNotFound() throws {
        let cmd = AddFeatureCommand(featureId: "feature1", geometryId: "geometry1", name: "", featureDescription: "")
        try realm.write {
            try cmd.apply(inRealm: realm)
        }
        let geometry = try XCTUnwrap(
            realm.object(ofType: Geometry.self, forPrimaryKey: "geometry1"),
            "geometry1 not found"
        )
        XCTAssertTrue(geometry.placeholder)
    }

    func testApplyInRealm_successful() throws {
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
        var cmd1 = AddFeatureCommand(
            featureId: "feature1",
            geometryId: "geometry1",
            name: "Feature1",
            featureDescription: ""
        )
        try realm.write {
            try cmd1.apply(inRealm: realm)
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
        cmd1.name = "Feature1..."
        try realm.write {
            try cmd1.apply(inRealm: realm)
        }
        XCTAssertEqual(geometry1.features.count, 1)
        XCTAssertEqual(geometry2.features.count, 0)
        XCTAssertEqual(feature1.name, "Feature1...")

        // 4. add another feature to geometry1
        let cmd2 = AddFeatureCommand(
            featureId: "feature2",
            geometryId: "geometry1",
            name: "Feature2",
            featureDescription: ""
        )
        try realm.write {
            try cmd2.apply(inRealm: realm)
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
