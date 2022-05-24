import PDFKit
@testable import Range
import XCTest

class PDFPageSize: XCTestCase {
    func testSizeInMeters() throws {
        guard let documentUrl = Bundle(for: type(of: self))
            .url(forResource: "test", withExtension: "pdf")
        else {
            XCTFail("test.pdf not found"); return
        }
        guard let document = PDFDocument(url: documentUrl) else {
            XCTFail("PDFDocument couldn't be created"); return
        }
        guard let pdfPage = document.page(at: 0) else {
            XCTFail("No page in PDF"); return
        }
        XCTAssertEqual(pdfPage.sizeInMeters(forScale: 1 / 48.0).width, 43.89, accuracy: 0.01)
        XCTAssertEqual(pdfPage.sizeInMeters(forScale: 1 / 48.0).height, 29.26, accuracy: 0.01)
    }
}
