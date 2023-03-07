@testable import Range
import RealmSwift
import XCTest

final class FirestoreCanvasTest: XCTestCase {
    let pendingUploadsModel = TestPendingUploadsModel()
    let pendingActionsModel = TestPendingActionsModel()
    var model: ProjectModel!
    var realm: Realm!

    @MainActor
    override func setUpWithError() throws {
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(
            userId: "user1",
            projectId: UUID().uuidString,
            localFiles: LocalFiles(),
            pendingUploadsModel: pendingUploadsModel,
            pendingActionsModel: pendingActionsModel,
            inMemory: true
        )
        realm = model.mainRealm
    }

    // MARK: - upsert tests

    // Tests creating/updating the object in local db from Firestore object

    /// Test that upserting a deprecated canvas with embedded pdf source data will create both canvas and canvasSource,
    /// and that a subsequent update to non-deprecated canvas will remove the "special" canvas source
    func testUpsert_deprecated() throws {
        // upsert deprecated canvas
        var firestoreCanvas = FirestoreCanvas(
            canvasCollectionId: "collection1",
            name: "canvas name",
            pageNumber: 1,
            sheetNumber: "A101",
            userDefinedScale: 48
        )
        try realm.write {
            try firestoreCanvas.upsert(withId: "canvas1", inRealm: realm)
        }
        let canvas1 = try XCTUnwrap(realm.object(ofType: Canvas.self, forPrimaryKey: "canvas1"), "canvas1 not found")
        XCTAssertEqual(canvas1.name, "canvas name")
        guard let source1 = canvas1.canvasSources.first else {
            XCTFail("canvas source not found"); return
        }
        XCTAssertEqual(source1.id, "canvas1_source") // special id based on canvas id
        XCTAssertEqual(source1.type, .pdf)
        XCTAssertEqual(source1.name, "")
        guard case let .pdf(pdfData) = source1.data else {
            XCTFail("unexpected canvas source data: \(source1.data)"); return
        }
        XCTAssertEqual(pdfData.sheetNumber, "A101")
        XCTAssertEqual(pdfData.pageNumber, 1)
        XCTAssertEqual(pdfData.userDefinedScale, 48)

        // update canvas so it's no longer deprecated, the "canvas1_source" should be gone
        firestoreCanvas.pageNumber = nil
        firestoreCanvas.sheetNumber = nil
        firestoreCanvas.userDefinedScale = nil
        try realm.write {
            try firestoreCanvas.upsert(withId: "canvas1", inRealm: realm)
        }
        XCTAssertTrue(canvas1.canvasSources.isEmpty)
        XCTAssertNil(realm.object(ofType: CanvasSource.self, forPrimaryKey: "canvas1_source"))
    }
}
