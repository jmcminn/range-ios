import Foundation
import RealmSwift

/// Represents the ``PDFCanvas`` (`projects/canvases` path in Firestore)
/// There's no support for encoding currently as it's a readonly data
struct FirestorePDFCanvas: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = PDFCanvas

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case canvasCollectionId = "canvasCollection", name, pageNumber, sheetNumber, userDefinedScale
    }

    var canvasCollectionId: String
    var name: String
    var pageNumber: Int
    var sheetNumber: String?
    var userDefinedScale: Double

    func upsert(withId id: String, inRealm realm: Realm) throws {
        let canvas = PDFCanvas(
            id: id,
            name: name,
            pageNumber: pageNumber,
            sheetNumber: sheetNumber,
            userDefinedScale: userDefinedScale
        )
        let collection = realm.objectOrPlaceholder(ofType: CanvasCollection.self, forPrimaryKey: canvasCollectionId)
        realm.add(canvas, update: .modified)
        collection.canvases.insert(canvas)
    }
}
