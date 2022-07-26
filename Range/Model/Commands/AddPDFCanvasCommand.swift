import Foundation
import RealmSwift

/// Add or update the `PDFCanvas`.
struct AddPDFCanvasCommand: Command, Equatable {
    let canvasId: String
    var url: String
    var pageNumber: Int
    var userDefinedScale: Double

    func apply(inRealm realm: Realm) throws {
        let canvas = PDFCanvas(id: canvasId, url: url, pageNumber: pageNumber, userDefinedScale: userDefinedScale)
        realm.add(canvas, update: .modified)
    }
}
