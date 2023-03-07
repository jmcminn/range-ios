import Foundation
import RealmSwift

/// Represents the ``CanvasSource`` (`projects/<id>/canvasSources/<id>` path in Firestore)
/// There's no support for encoding currently as it's a readonly data
struct FirestoreCanvasSource: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = CanvasSource

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case canvasId = "canvas", name, typeString = "type"
    }

    var canvasId: String
    var name: String
    var data: CanvasSourceData

    init(canvasId: String, name: String, data: CanvasSourceData) {
        self.canvasId = canvasId
        self.name = name
        self.data = data
    }

    /// Custom implementation of decoding that decodes straight to CanvasSourceData (so this class doesn't have
    /// to bother with details of decoding different types for CanvasSource
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        canvasId = try container.decode(String.self, forKey: .canvasId)
        name = try container.decode(String.self, forKey: .name)
        let typeString = try container.decode(String.self, forKey: .typeString)
        guard let type = CanvasSourceType(fromString: typeString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .typeString,
                in: container,
                debugDescription: "Unsupported type: \(typeString)"
            )
        }
        let dataContainer = try decoder.singleValueContainer()
        switch type {
        case .pdf:
            data = .pdf(try dataContainer.decode(PdfCanvasSourceData.self))
        case .mapbox:
            data = .mapbox(try dataContainer.decode(MapboxCanvasSourceData.self))
        case .droneDeploy:
            data = .droneDeploy(try dataContainer.decode(DroneDeployCanvasSourceData.self))
        }
    }

    func upsert(withId id: String, inRealm realm: Realm) throws {
        let canvas = realm.objectOrPlaceholder(ofType: Canvas.self, forPrimaryKey: canvasId)
        let canvasSource = CanvasSource(id: id, name: name, data: data)
        realm.add(canvasSource, update: .modified)
        canvas.canvasSources.insert(canvasSource)
    }
}
