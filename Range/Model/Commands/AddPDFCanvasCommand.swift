import Foundation
import RealmSwift

struct AddPDFCanvasCommand: Command {
    let canvasId: String
    var url: String
    var pageNumber: Int
    var userDefinedScale: Double

    func applyLocally(inRealm realm: Realm) throws {
        let canvas = PDFCanvas(id: canvasId, url: url, pageNumber: pageNumber, userDefinedScale: userDefinedScale)
        realm.add(canvas, update: .modified)
    }
}
