import Foundation

/// Decodable for ``PDFCanvas`` (`projects/details/canvases` path in Firebase)
/// There's no support for encoding currently as it's a readonly data
struct FirebasePDFCanvas: Decodable {
    let id: String
    let url: String
    let pageNumber: Int
    let userDefinedScale: Double

    var pdfCanvas: PDFCanvas {
        PDFCanvas(id: id, url: url, pageNumber: pageNumber, userDefinedScale: userDefinedScale)
    }
}
