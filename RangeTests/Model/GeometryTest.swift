import CoreLocation
import XCTest

class GeometryTest: XCTestCase {
    func testEncode() throws {
        let point = GeoJSONPointGeometry(position: CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5))
        let geometry = Geometry(id: "1234", pointGeometry: point)
        let data = try JSONEncoder().encode(geometry)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            XCTFail("no JSON string"); return
        }
        let expectedJSONString = """
        {"id":"1234","geometry":{"type":"Point","coordinates":[-96.5,32.5]}}
        """
        XCTAssertEqual(jsonString, expectedJSONString)
    }

    func testDecodeUnsupportedType() {
        let inputString = """
        {
            "id": "1234",
            "geometry": {
                "type": "Polygon",
                "coordinates":[-96.5,32.5]
            }
        }
        """
        guard let inputData = inputString.data(using: .utf8) else {
            XCTFail("no input data"); return
        }
        XCTAssertThrowsError(
            try JSONDecoder().decode(Geometry.self, from: inputData)
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

    func testDecode() throws {
        let inputString = """
        {
            "id": "1234",
            "geometry": {
                "type": "Point",
                "coordinates": [-96.77546339604037, 32.82483564429168]
            }
        }
        """
        guard let inputData = inputString.data(using: .utf8) else {
            XCTFail("no input data"); return
        }
        let geometry = try JSONDecoder().decode(Geometry.self, from: inputData)
        XCTAssertEqual(geometry.id, "1234")
        guard case let .point(geoJSONPointGeometry) = geometry.geoJSONGeometry else {
            XCTFail("unexpected geometry type: \(geometry.geoJSONGeometry)"); return
        }
        XCTAssertEqual(geoJSONPointGeometry.position.longitude, -96.775463396, accuracy: 0.000000001)
        XCTAssertEqual(geoJSONPointGeometry.position.latitude, 32.824835644, accuracy: 0.000000001)
    }
}
