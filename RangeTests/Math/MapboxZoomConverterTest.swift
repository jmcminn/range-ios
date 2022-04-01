import XCTest

class MapboxZoomConverterTest: XCTestCase {
    
    func testGetZoom() throws {
        XCTAssertEqual(
            MapboxZoomConverter(latitude: 32.829935).getZoom(forMetersPerPoint: 0.5),
            17,
            accuracy: 0.01)
    }
    
    func testGetMetersPerPoint() throws {
        XCTAssertEqual(
            MapboxZoomConverter(latitude: 32.829935).getMetersPerPoint(forZoom: 17),
            0.5,
            accuracy: 0.01)
    }
    
}
