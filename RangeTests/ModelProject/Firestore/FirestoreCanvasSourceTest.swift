@testable import Range
import RealmSwift
import XCTest

final class FirestoreCanvasSourceTest: ProjectModelTestCase {
    // MARK: - decode tests

    func testDecode_unsupportedType() {
        let inputString = """
        {
            "canvas": "5678",
            "name": "",
            "type": "png"
        }
        """
        guard let inputData = inputString.data(using: .utf8) else {
            XCTFail("no input data"); return
        }
        XCTAssertThrowsError(
            try JSONDecoder().decode(FirestoreCanvasSource.self, from: inputData)
        ) { error in
            guard
                let error = error as? DecodingError,
                case let .dataCorrupted(context) = error
            else {
                XCTFail("unexpected error: \(error)"); return
            }
            XCTAssertEqual(context.debugDescription, "Unsupported type: png")
        }
    }

    func testDecode_pdf() throws {
        let inputString = """
        {
            "canvas": "5678",
            "name": "canvas source name",
            "type": "pdf",
            "sheetNumber": "A01",
            "pageNumber": 1,
            "userDefinedScale": 48
        }
        """
        guard let inputData = inputString.data(using: .utf8) else {
            XCTFail("no input data"); return
        }
        let decodedSource = try JSONDecoder().decode(FirestoreCanvasSource.self, from: inputData)
        XCTAssertEqual(decodedSource.canvasId, "5678")
        XCTAssertEqual(decodedSource.name, "canvas source name")
        XCTAssertEqual(decodedSource.data.type, .pdf)
        guard case let .pdf(pdfData) = decodedSource.data else {
            XCTFail("unexpected canvas source data: \(decodedSource.data)"); return
        }
        XCTAssertEqual(pdfData.sheetNumber, "A01")
        XCTAssertEqual(pdfData.userDefinedScale, 48)
    }

    // MARK: - upsert tests

    // Tests creating/updating the object in local db from Firestore object

    // Adds a canvas placeholder if canvas not found
    func testUpsert_canvasNotFound() throws {
        let firestoreSource = FirestoreCanvasSource(
            canvasId: "canvas1", name: "",
            data: .pdf(PdfCanvasSourceData(userDefinedScale: 1))
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
            canvasId: "canvas1", name: "canvas source name",
            data: .pdf(PdfCanvasSourceData(userDefinedScale: 48))
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
        guard case let .pdf(pdfData) = source1.data else {
            XCTFail("unexpected canvas source data: \(source1.data)"); return
        }
        XCTAssertEqual(pdfData.sheetNumber, nil)
        XCTAssertEqual(pdfData.userDefinedScale, 48)
    }
}
