@testable import Range
import RealmSwift
import XCTest

final class FirestoreCanvasTest: ProjectModelTestCase {
    // MARK: - upsert tests

    // Tests creating/updating the object in local db from Firestore object

    func testUpsert_deprecated() throws {
        // upsert deprecated canvas
        var firestoreCanvas = FirestoreCanvas(name: "canvas name")
        try realm.write {
            try firestoreCanvas.upsert(withId: "canvas1", inRealm: realm)
        }
        let canvas1 = try XCTUnwrap(realm.object(ofType: Canvas.self, forPrimaryKey: "canvas1"), "canvas1 not found")
        XCTAssertEqual(canvas1.name, "canvas name")
    }
}
