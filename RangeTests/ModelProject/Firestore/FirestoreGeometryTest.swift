import CoreLocation
@testable import Range
import RealmSwift
import Turf
import XCTest

class FirestoreGeometryTest: ProjectModelTestCase {
    // MARK: - decode tests

    func testDecode_unsupportedType() {
        let inputString = """
        {
            "canvas": "5678",
            "annotationType": "polygon",
            "coordinates": "[-96.5, 32.5]"
        }
        """
        guard let inputData = inputString.data(using: .utf8) else {
            XCTFail("no input data"); return
        }
        XCTAssertThrowsError(
            try JSONDecoder().decode(FirestoreGeometry.self, from: inputData)
        ) { error in
            guard
                let error = error as? DecodingError,
                case let .dataCorrupted(context) = error
            else {
                XCTFail("unexpected error: \(error)"); return
            }
            XCTAssertEqual(context.debugDescription, "Unsupported annotationType: polygon")
        }
    }

    func testDecode() throws {
        let inputString = """
        {
            "canvas": "5678",
            "annotationType": "photoMarker",
            "coordinates": "[-96.5, 32.5]"
        }
        """
        guard let inputData = inputString.data(using: .utf8) else {
            XCTFail("no input data"); return
        }
        let decodedGeometry = try JSONDecoder().decode(FirestoreGeometry.self, from: inputData)
        XCTAssertEqual(decodedGeometry.canvasId, "5678")
        XCTAssertEqual(decodedGeometry.annotationType, .photoMarker)
        guard case let .point(point) = decodedGeometry.geometry else {
            XCTFail("unexpected geometry type: \(decodedGeometry.geometry)"); return
        }
        XCTAssertEqual(point.coordinates.longitude, -96.5, accuracy: 0.000000001)
        XCTAssertEqual(point.coordinates.latitude, 32.5, accuracy: 0.000000001)
    }

    // MARK: - upsert tests

    // Tests creating/updating the object in local db from Firestore object

    // Adds a canvas placeholder if canvas not found
    func testUpsert_canvasNotFound() throws {
        let firestoreGeometry = FirestoreGeometry(
            canvasId: "canvas1",
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        )
        try realm.write {
            try firestoreGeometry.upsert(withId: "geometry1", inRealm: realm)
        }
        let canvas = try XCTUnwrap(realm.object(ofType: Canvas.self, forPrimaryKey: "canvas1"), "canvas1 not found")
        XCTAssertTrue(canvas.placeholder)
    }

    func testUpsert() throws {
        // 1. create 2 empty canvases
        let canvas1 = Canvas(id: "canvas1", name: "")
        let canvas2 = Canvas(id: "canvas2", name: "")
        try realm.write {
            realm.add([canvas1, canvas2])
        }
        XCTAssertEqual(canvas1.geometries.count, 0)
        XCTAssertEqual(canvas2.geometries.count, 0)

        // 2. add geometry to canvas1
        var firestoreGeometry1 = FirestoreGeometry(
            canvasId: "canvas1",
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        )
        try realm.write {
            try firestoreGeometry1.upsert(withId: "geometry1", inRealm: realm)
        }
        XCTAssertEqual(canvas1.geometries.count, 1)
        XCTAssertEqual(canvas2.geometries.count, 0)
        let geometry1 = try XCTUnwrap(
            realm.object(ofType: Geometry.self, forPrimaryKey: "geometry1"),
            "geometry1 not found"
        )
        XCTAssertEqual(geometry1.annotationType, .photoMarker)
        XCTAssertEqual(geometry1.geometry, .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5))))

        // 3. update the geometry in canvas1
        firestoreGeometry1.geometry = .point(Point(CLLocationCoordinate2D(latitude: 32.6, longitude: -96.5)))
        try realm.write {
            try firestoreGeometry1.upsert(withId: "geometry1", inRealm: realm)
        }
        XCTAssertEqual(canvas1.geometries.count, 1)
        XCTAssertEqual(canvas2.geometries.count, 0)
        XCTAssertEqual(geometry1.geometry, .point(Point(CLLocationCoordinate2D(latitude: 32.6, longitude: -96.5))))

        // 4. add another geometry to canvas1
        let firestoreGeometry2 = FirestoreGeometry(
            canvasId: "canvas1",
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.7, longitude: -96.5)))
        )
        try realm.write {
            try firestoreGeometry2.upsert(withId: "geometry2", inRealm: realm)
        }
        XCTAssertEqual(canvas1.geometries.count, 2)
        XCTAssertEqual(canvas2.geometries.count, 0)

        // 5. remove geometry2
        try realm.write {
            let geometry2 = try XCTUnwrap(
                realm.object(ofType: Geometry.self, forPrimaryKey: "geometry2"),
                "geometry2 not found"
            )
            realm.delete(geometry2)
        }
        XCTAssertEqual(canvas1.geometries.count, 1)
        XCTAssertEqual(canvas2.geometries.count, 0)
        XCTAssertEqual(canvas1.geometries.first?.id, "geometry1")
    }

    func testUpsert_switchCanvas() throws {
        // 1. create 2 canvases and geometry in canvas1
        let canvas1 = Canvas(id: "canvas1", name: "")
        let canvas2 = Canvas(id: "canvas2", name: "")
        var geometry1 = Geometry(placeholderId: "geometry1")
        try realm.write {
            realm.add([canvas1, canvas2, geometry1])
            canvas1.geometries.insert(geometry1)
        }
        XCTAssertEqual(canvas1.geometries.count, 1)
        XCTAssertEqual(canvas2.geometries.count, 0)

        // when moving the geometry to canvas2
        let firestoreGeometry1 = FirestoreGeometry(
            canvasId: "canvas2",
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        )
        try realm.write {
            try firestoreGeometry1.upsert(withId: "geometry1", inRealm: realm)
        }

        // the geometry should be now in 2nd canvas, and removed from the first
        XCTAssertEqual(canvas1.geometries.count, 0)
        XCTAssertEqual(canvas2.geometries.count, 1)
    }
}
