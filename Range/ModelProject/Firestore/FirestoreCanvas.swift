import Foundation
import RealmSwift

/// Represents the ``Canvas`` (`projects/canvases` path in Firestore)
/// There's no support for encoding currently as it's a readonly data
struct FirestoreCanvas: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = Canvas

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case canvasCollectionId = "canvasCollection", name, pageNumber, sheetNumber,
             userDefinedScale
    }

    var canvasCollectionId: String
    var name: String
    var pageNumber: Int? // for deprecated pdf onl, not there in new sources based canvas
    var sheetNumber: String? // for deprecated pdf onl, not there in new sources based canvas
    var userDefinedScale: Double? // for deprecated pdf onl, not there in new sources based canvas

    func upsert(withId id: String, inRealm realm: Realm) throws {
        let collection = realm.objectOrPlaceholder(ofType: CanvasCollection.self, forPrimaryKey: canvasCollectionId)
        let canvas = Canvas(id: id, name: name)
        realm.add(canvas, update: .modified)
        collection.canvases.insert(canvas)
        // special id for canvas source based on the deprecated canvas (which includes pdf source data, but no id for source)
        let deprecatedCanvasSourceId = id + "_source"
        if let pageNumber = pageNumber, let userDefinedScale = userDefinedScale {
            // add a canvas source based on the deprecated canvas data
            let canvasSource = CanvasSource(
                id: deprecatedCanvasSourceId,
                name: "",
                data: .pdf(PdfCanvasSourceData(
                    sheetNumber: sheetNumber,
                    pageNumber: pageNumber,
                    userDefinedScale: userDefinedScale
                ))
            )
            realm.add(canvasSource, update: .modified)
            canvas.canvasSources.insert(canvasSource)
        } else {
            // remove the canvas source based on the deprecated canvas if it was added to realm previously
            if let deprecatedSource = realm.object(ofType: CanvasSource.self, forPrimaryKey: deprecatedCanvasSourceId) {
                realm.delete(deprecatedSource)
            }
        }
    }
}
