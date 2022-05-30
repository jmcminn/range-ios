import Foundation
import RealmSwift

/// Represents the ``PDFCanvas`` (`projects/details/canvases` path in Firebase)
/// There's no support for encoding currently as it's a readonly data
struct FirebasePDFCanvas: Decodable, FirebaseToRealmSyncable {
    typealias ModelType = PDFCanvas
    var id: String
    var url: String
    var pageNumber: Int
    var userDefinedScale: Double

    /// Adds or updates the canvas to Realm database.
    func upsert(_ realm: Realm) throws {
        let canvas = PDFCanvas(id: id, url: url, pageNumber: pageNumber, userDefinedScale: userDefinedScale)
        realm.add(canvas, update: .modified)
    }
}
