import CoreLocation
@testable import Range
import RealmSwift
import XCTest

final class FirestoreCanvasSourceTest: ProjectModelTestCase {
    // MARK: - upsert tests

    // Tests creating/updating the object in local db from Firestore object

    // Adds a canvas placeholder if canvas not found
    func testUpsert_canvasNotFound() throws {
        let firestoreSource = FirestoreCanvasSource(
            canvasId: "canvas1", center: LocationCoordinate2DCodable(CLLocationCoordinate2D(latitude: 0, longitude: 0)),
            name: "", typeString: "pdf"
        )
        try realm.write {
            try firestoreSource.upsert(withId: "canvasSource1", inRealm: realm)
        }
        let canvas = try XCTUnwrap(realm.object(ofType: Canvas.self, forPrimaryKey: "canvas1"), "canvas1 not found")
        XCTAssertTrue(canvas.placeholder)
    }

    func testUpsert() throws {
        // 1. create canvas
        let canvas1 = Canvas(id: "canvas1", name: "")
        try realm.write {
            realm.add(canvas1)
        }
        XCTAssertEqual(canvas1.canvasSources.count, 0)

        // 2. add source to canvas1
        let firestoreSource1 = FirestoreCanvasSource(
            canvasId: "canvas1", center: LocationCoordinate2DCodable(CLLocationCoordinate2D(latitude: 0, longitude: 0)),
            name: "canvas source name", typeString: "pdf", userDefinedScale: 48
        )
        try realm.write {
            try firestoreSource1.upsert(withId: "canvasSource1", inRealm: realm)
        }
        XCTAssertEqual(canvas1.canvasSources.count, 1)
        let source1 = try XCTUnwrap(
            realm.object(ofType: CanvasSource.self, forPrimaryKey: "canvasSource1"),
            "canvasSource1 not found"
        )
        XCTAssertEqual(source1.type, .pdf)
        XCTAssertEqual(source1.name, "canvas source name")
        XCTAssertEqual(source1.canvas.first, canvas1)
        XCTAssertEqual(source1.userDefinedScale, 48)
    }
}
