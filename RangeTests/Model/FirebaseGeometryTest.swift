import CoreLocation
@testable import Range
import Turf
import XCTest

class FirebaseGeometryTest: XCTestCase {
    func testEncode_unsupportedGeometry() throws {
        let geometry = FirebaseGeometry(
            canvasId: "5678",
            geometry: .lineString(LineString([CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)]))
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
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        )
        let data = try JSONEncoder().encode(geometry)

        let decodedGeometry = try JSONDecoder().decode(FirebaseGeometry.self, from: data)
        XCTAssertEqual(decodedGeometry.canvasId, "5678")
        XCTAssertEqual(decodedGeometry.annotationType, .photoMarker)
        guard case let .point(point) = decodedGeometry.geometry else {
            XCTFail("unexpected geometry type: \(decodedGeometry.geometry)"); return
        }
        XCTAssertEqual(point.coordinates.longitude, -96.5, accuracy: 0.000000001)
        XCTAssertEqual(point.coordinates.latitude, 32.5, accuracy: 0.000000001)
    }

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
            "canvas": "5678",
            "annotationType": "photoMarker",
            "coordinates": "[-96.5, 32.5]"
        }
        """
        guard let inputData = inputString.data(using: .utf8) else {
            XCTFail("no input data"); return
        }
        let decodedGeometry = try JSONDecoder().decode(FirebaseGeometry.self, from: inputData)
        XCTAssertEqual(decodedGeometry.canvasId, "5678")
        XCTAssertEqual(decodedGeometry.annotationType, .photoMarker)
        guard case let .point(point) = decodedGeometry.geometry else {
            XCTFail("unexpected geometry type: \(decodedGeometry.geometry)"); return
        }
        XCTAssertEqual(point.coordinates.longitude, -96.5, accuracy: 0.000000001)
        XCTAssertEqual(point.coordinates.latitude, 32.5, accuracy: 0.000000001)
    }

    // Tests if firebase object creates a proper upsert command
    func testUpsertCommand() throws {
        let firebaseGeometry = FirebaseGeometry(
            canvasId: "canvas1",
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        )
        XCTAssertEqual(
            try firebaseGeometry.upsertCommand(id: "geometry1") as? UpsertGeometryCommand,
            UpsertGeometryCommand(
                geometryId: "geometry1",
                canvasId: "canvas1",
                annotationType: .photoMarker,
                geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
            )
        )
    }
}
