import CoreLocation
import XCTest

class GeoJSONPointGeometryTest: XCTestCase {
    func testEncode() throws {
        let point = GeoJSONPointGeometry(position: CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5))
        let data = try JSONEncoder().encode(point)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            XCTFail("no JSON string"); return
        }
        let expectedJSONString = """
        {"type":"Point","coordinates":[-96.5,32.5]}
        """
        XCTAssertEqual(jsonString, expectedJSONString)
    }

    func testDecodeWrongType() {
        let inputString = """
        {
            "type": "Polygon",
            "coordinates":[-96.5,32.5]
        }
        """
        guard let inputData = inputString.data(using: .utf8) else {
            XCTFail("no input data"); return
        }
        XCTAssertThrowsError(
            try JSONDecoder().decode(GeoJSONPointGeometry.self, from: inputData)
        ) { error in
            guard
                let error = error as? DecodingError,
                case let .dataCorrupted(context) = error
            else {
                XCTFail("unexpected error: \(error)"); return
            }
            XCTAssertEqual(context.debugDescription, "Unsupported type")
        }
    }

    func testDecodeWrongCoordinates() {
        let inputString = """
        {
            "type": "Point",
            "coordinates": [[-96.5,32.5]]
        }
        """
        guard let inputData = inputString.data(using: .utf8) else {
            XCTFail("no input data"); return
        }
        XCTAssertThrowsError(
            try JSONDecoder().decode(GeoJSONPointGeometry.self, from: inputData)
        ) { error in
            guard
                let error = error as? DecodingError,
                case let .typeMismatch(_, context) = error
            else {
                XCTFail("unexpected error: \(error)"); return
            }
            XCTAssertEqual(context.debugDescription, "Expected to decode Double but found an array instead.")
        }
    }

    func testDecode() throws {
        let inputString = """
        {
            "type": "Point",
            "coordinates": [-96.77546339604037, 32.82483564429168]
        }
        """
        guard let inputData = inputString.data(using: .utf8) else {
            XCTFail("no input data"); return
        }
        let point = try JSONDecoder().decode(GeoJSONPointGeometry.self, from: inputData)
        XCTAssertEqual(point.position.longitude, -96.775463396, accuracy: 0.000000001)
        XCTAssertEqual(point.position.latitude, 32.824835644, accuracy: 0.000000001)
    }
}
