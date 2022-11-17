import Foundation
import RealmSwift

/// Represents the ``PDFCanvas`` (`projects/canvases` path in Firebase)
/// There's no support for encoding currently as it's a readonly data
struct FirebasePDFCanvas: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = PDFCanvas
    var pageNumber: Int
    var userDefinedScale: Double

    func upsert(withId id: String, inRealm realm: Realm) throws {
        let canvas = PDFCanvas(id: id, pageNumber: pageNumber, userDefinedScale: userDefinedScale)
        realm.add(canvas, update: .modified)
    }
}
