import CoreLocation
@testable import Range
import RealmSwift
import Turf
import XCTest

class FirebaseGeometryEncodingTest: XCTestCase {
    func testEncode_unsupportedGeometry() throws {
        let geometry = FirebaseGeometry(
            canvasId: "5678",
            geometry: Geometry(
                id: "1234",
                annotationType: .photoMarker,
                geometry: .lineString(LineString([CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)]))
            )
        )
        XCTAssertThrowsError(
            try JSONEncoder().encode(geometry)
        ) { error in
            guard
                let error = error as? EncodingError,
                case let .invalidValue(_, context) = error
            else {
                XCTFail("unexpected error: \(error)"); return
            }
            XCTAssertEqual(context.debugDescription, "Unsupported geometry")
        }
    }

    func testEncode() throws {
        let geometry = FirebaseGeometry(
            canvasId: "5678",
            geometry: Geometry(
                id: "1234",
                annotationType: .photoMarker,
                geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
            )
        )
        let data = try JSONEncoder().encode(geometry)

        let decodedGeometry = try JSONDecoder().decode(FirebaseGeometry.self, from: data)
        XCTAssertEqual(decodedGeometry.geometry.id, "1234")
        XCTAssertEqual(decodedGeometry.canvasId, "5678")
        XCTAssertEqual(decodedGeometry.geometry.annotationType, .photoMarker)
        guard case let .point(point) = decodedGeometry.geometry.geometry else {
            XCTFail("unexpected geometry type: \(decodedGeometry.geometry)"); return
        }
        XCTAssertEqual(point.coordinates.longitude, -96.5, accuracy: 0.000000001)
        XCTAssertEqual(point.coordinates.latitude, 32.5, accuracy: 0.000000001)
    }

    func testDecode_unsupportedType() {
        let inputString = """
        {
            "id": "1234",
            "canvas": "5678",
            "annotationType": "polygon",
            "coordinates": [-96.5, 32.5]
        }
        """
        guard let inputData = inputString.data(using: .utf8) else {
            XCTFail("no input data"); return
        }
        XCTAssertThrowsError(
            try JSONDecoder().decode(FirebaseGeometry.self, from: inputData)
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
            "id": "1234",
            "canvas": "5678",
            "annotationType": "photoMarker",
            "coordinates": [-96.5, 32.5]
        }
        """
        guard let inputData = inputString.data(using: .utf8) else {
            XCTFail("no input data"); return
        }
        let decodedGeometry = try JSONDecoder().decode(FirebaseGeometry.self, from: inputData)
        XCTAssertEqual(decodedGeometry.geometry.id, "1234")
        XCTAssertEqual(decodedGeometry.canvasId, "5678")
        XCTAssertEqual(decodedGeometry.geometry.annotationType, .photoMarker)
        guard case let .point(point) = decodedGeometry.geometry.geometry else {
            XCTFail("unexpected geometry type: \(decodedGeometry.geometry)"); return
        }
        XCTAssertEqual(point.coordinates.longitude, -96.5, accuracy: 0.000000001)
        XCTAssertEqual(point.coordinates.latitude, 32.5, accuracy: 0.000000001)
    }
}

class FirebaseGeometryRealmSyncTest: XCTestCase {
    var model: ProjectModel!
    var realm: Realm!

    override func setUpWithError() throws {
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(projectId: UUID().uuidString, inMemory: true)
        realm = model.mainRealm
    }

    // Throws when adding geometry to not existing canvas
    func testUpsert_canvasNotFound() throws {
        let firebaseGeometry = FirebaseGeometry(
            canvasId: "canvas1",
            geometry: Geometry(
                id: "geometry1",
                annotationType: .photoMarker,
                geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
            )
        )
        try realm.write {
            XCTAssertThrowsError(
                try firebaseGeometry.upsert(realm)
            ) { error in
                XCTAssertEqual(error.localizedDescription, "canvas not found: canvas1")
            }
        }
    }

    // Tests that geometries are added to the canvas
    func testUpsert_successful() throws {
        // 1. create 2 empty canvases
        let canvas1 = PDFCanvas(id: "canvas1", url: "url1", pageNumber: 0, userDefinedScale: 1)
        let canvas2 = PDFCanvas(id: "canvas2", url: "url2", pageNumber: 0, userDefinedScale: 1)
        try realm.write {
            realm.add([canvas1, canvas2])
        }
        XCTAssertEqual(canvas1.geometries.count, 0)
        XCTAssertEqual(canvas2.geometries.count, 0)

        // 2. add geometry to canvas1
        var firebaseGeometry1 = FirebaseGeometry(
            canvasId: "canvas1",
            geometry: Geometry(
                id: "geometry1",
                annotationType: .photoMarker,
                geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
            )
        )
        try realm.write {
            try firebaseGeometry1.upsert(realm)
        }
        XCTAssertEqual(canvas1.geometries.count, 1)
        XCTAssertEqual(canvas2.geometries.count, 0)
        guard let geometry1 = realm.object(ofType: Geometry.self, forPrimaryKey: "geometry1") else {
            throw "geometry1 not found"
        }
        XCTAssertEqual(geometry1.annotationType, .photoMarker)
        XCTAssertEqual(geometry1.geometry, .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5))))

        // 3. update the geometry in canvas1
        firebaseGeometry1.geometry = Geometry(
            id: "geometry1",
            annotationType: .photoMarker,
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.6, longitude: -96.5)))
        )
        try realm.write {
            try firebaseGeometry1.upsert(realm)
        }
        XCTAssertEqual(canvas1.geometries.count, 1)
        XCTAssertEqual(canvas2.geometries.count, 0)
        XCTAssertEqual(geometry1.geometry, .point(Point(CLLocationCoordinate2D(latitude: 32.6, longitude: -96.5))))

        // 4. add another geometry to canvas1
        let firebaseGeometry2 = FirebaseGeometry(
            canvasId: "canvas1",
            geometry: Geometry(
                id: "geometry2",
                annotationType: .photoMarker,
                geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.7, longitude: -96.5)))
            )
        )
        try realm.write {
            try firebaseGeometry2.upsert(realm)
        }
        XCTAssertEqual(canvas1.geometries.count, 2)
        XCTAssertEqual(canvas2.geometries.count, 0)

        // 5. remove geometry2
        try realm.write {
            guard let geometry2 = realm.object(ofType: Geometry.self, forPrimaryKey: "geometry2") else {
                throw "geometry2 not found"
            }
            realm.delete(geometry2)
        }
        XCTAssertEqual(canvas1.geometries.count, 1)
        XCTAssertEqual(canvas2.geometries.count, 0)
        XCTAssertEqual(canvas1.geometries.first?.id, "geometry1")
    }
}
