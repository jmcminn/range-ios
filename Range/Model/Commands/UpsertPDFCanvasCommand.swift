import Foundation
import RealmSwift

/// Add or update the `PDFCanvas` in local Realm db.
struct UpsertPDFCanvasCommand: LocalCommand, Equatable {
    let canvasId: String
    var pageNumber: Int
    var userDefinedScale: Double

    func apply(inRealm realm: Realm) throws {
        let canvas = PDFCanvas(id: canvasId, pageNumber: pageNumber, userDefinedScale: userDefinedScale)
        realm.add(canvas, update: .modified)
    }
}
