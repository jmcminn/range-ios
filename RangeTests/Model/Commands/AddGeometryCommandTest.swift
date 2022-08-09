import CoreLocation
@testable import Range
import RealmSwift
import Turf
import XCTest

class AddGeometryCommandTest: XCTestCase {
    var pendingUploadsModel: PendingUploadsModel!
    var model: ProjectModel!
    var realm: Realm!

    @MainActor
    override func setUpWithError() throws {
        pendingUploadsModel = TestPendingUploadsModel()
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(
            userId: "user1",
            projectId: UUID().uuidString,
            pendingUploadsModel: pendingUploadsModel,
            inMemory: true
        )
        realm = model.mainRealm
    }

    // Adds a canvas placeholder if canvas not found
    func testApplyInRealm_canvasNotFound() throws {
        let cmd = AddGeometryCommand(
            geometryId: "geometry1",
            canvasId: "canvas1",
            annotationType: .photoMarker,
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        )
        try realm.write {
            try cmd.apply(inRealm: realm)
        }
        let canvas = try XCTUnwrap(realm.object(ofType: PDFCanvas.self, forPrimaryKey: "canvas1"), "canvas1 not found")
        XCTAssertTrue(canvas.placeholder)
    }

    // Tests that geometries are added to the canvas
    func testApplyInRealm_successful() throws {
        // 1. create 2 empty canvases
        let canvas1 = PDFCanvas(id: "canvas1", url: "url1", pageNumber: 0, userDefinedScale: 1)
        let canvas2 = PDFCanvas(id: "canvas2", url: "url2", pageNumber: 0, userDefinedScale: 1)
        try realm.write {
            realm.add([canvas1, canvas2])
        }
        XCTAssertEqual(canvas1.geometries.count, 0)
        XCTAssertEqual(canvas2.geometries.count, 0)

        // 2. add geometry to canvas1
        var cmd1 = AddGeometryCommand(
            geometryId: "geometry1",
            canvasId: "canvas1",
            annotationType: .photoMarker,
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        )
        try realm.write {
            try cmd1.apply(inRealm: realm)
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
        cmd1.geometry = .point(Point(CLLocationCoordinate2D(latitude: 32.6, longitude: -96.5)))
        try realm.write {
            try cmd1.apply(inRealm: realm)
        }
        XCTAssertEqual(canvas1.geometries.count, 1)
        XCTAssertEqual(canvas2.geometries.count, 0)
        XCTAssertEqual(geometry1.geometry, .point(Point(CLLocationCoordinate2D(latitude: 32.6, longitude: -96.5))))

        // 4. add another geometry to canvas1
        let cmd2 = AddGeometryCommand(
            geometryId: "geometry2",
            canvasId: "canvas1",
            annotationType: .photoMarker,
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.7, longitude: -96.5)))
        )
        try realm.write {
            try cmd2.apply(inRealm: realm)
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
}
