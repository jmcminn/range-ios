import Foundation
import RealmSwift

/// Represents the ``PDFCanvas`` (`projects/canvases` path in Firebase)
/// There's no support for encoding currently as it's a readonly data
struct FirebasePDFCanvas: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = PDFCanvas
    var url: String
    var pageNumber: Int
    var userDefinedScale: Double

    func upsertCommand(id: String) throws -> Command {
        AddPDFCanvasCommand(canvasId: id, url: url, pageNumber: pageNumber, userDefinedScale: userDefinedScale)
    }
}
