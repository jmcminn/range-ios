import CoreLocation
import FirebaseFirestore
@testable import Range
import RealmSwift
import Turf
import XCTest

/// Tests applying `UpdateGeometryLocationCommand` in local Realm db
final class UpdateGeometryLocationCommandRealmTest: ProjectModelTestCase {
    func testApply_noGeometry() throws {
        let command = try UpdateGeometryLocationCommand(
            collaborationId: "collaboration1",
            canvasId: "canvas1",
            coordinates: CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)
        )
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.geometryNotFound)
        }
    }

    func testApply_noCanvas() throws {
        let geometry = Geometry(
            id: "geometry1",
            annotationType: .photoMarker,
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        )
        let collaboration = Collaboration(placeholderId: "collaboration1")
        try realm.write {
            realm.add([geometry, collaboration])
            geometry.collaborations.insert(collaboration)
        }

        let command = try UpdateGeometryLocationCommand(
            collaborationId: "collaboration1",
            canvasId: "canvas2",
            coordinates: CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)
        )
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.canvasNotFound)
        }
    }

    func testApply_successful() throws {
        let geometry = Geometry(
            id: "geometry1",
            annotationType: .photoMarker,
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        )
        let collaboration = Collaboration(placeholderId: "collaboration1")
        let canvas1 = Canvas(placeholderId: "canvas1")
        let canvas2 = Canvas(placeholderId: "canvas2")
        try realm.write {
            realm.add([geometry, collaboration, canvas1, canvas2])
            geometry.collaborations.insert(collaboration)
            canvas1.geometries.insert(geometry)
        }
        let command = try UpdateGeometryLocationCommand(
            collaborationId: "collaboration1",
            canvasId: "canvas2",
            coordinates: CLLocationCoordinate2D(latitude: 33.5, longitude: -96.5)
        )
        try realm.write {
            try command.apply(inRealm: realm)
        }
        XCTAssertTrue(canvas1.geometries.isEmpty)
        XCTAssertTrue(canvas2.geometries.contains(geometry))
        XCTAssertEqual(geometry.geometry, .point(Point(CLLocationCoordinate2D(latitude: 33.5, longitude: -96.5))))
    }
}

/// Tests getting the parameters for Firebase function call
final class UpdateGeometryLocationCommandFirebaseFunctionTest: XCTestCase {
    func testApply_successful() throws {
        let archivedTimestamp = Date()
        let command = try UpdateGeometryLocationCommand(
            collaborationId: "collaboration1",
            canvasId: "canvas2",
            coordinates: CLLocationCoordinate2D(latitude: 33.5, longitude: -96.5)
        )
        XCTAssertEqual(command.functionName, "updateCollaboration")

        let data = command.functionData("project1") as? [String: Any?]
        let expected: [String: Any?] = [
            "projectId": "project1",
            "collaborationId": "collaboration1",
            "canvasId": "canvas2",
            "coordinates": "[-96.5,33.5]",
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
}
