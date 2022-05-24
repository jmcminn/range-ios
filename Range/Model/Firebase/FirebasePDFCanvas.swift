import Foundation

/// Decodable for ``PDFCanvas`` (`projects/details/canvases` path in Firebase)
/// There's no support for encoding currently as it's a readonly data
struct FirebasePDFCanvas: Decodable {
    /// The decoded pdf canvas
    let pdfCanvas: PDFCanvas

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case id
        case url
        case pageNumber
        case userDefinedScale
    }

    /// Custom implementation of decoding that checks for proper type and translates the `coordinates` array into `position`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let url = try container.decode(String.self, forKey: .url)
        let pageNumber = try container.decode(Int.self, forKey: .pageNumber)
        let userDefinedScale = try container.decode(Double.self, forKey: .userDefinedScale)
        pdfCanvas = PDFCanvas(id: id, url: url, pageNumber: pageNumber, userDefinedScale: userDefinedScale)
    }
}
