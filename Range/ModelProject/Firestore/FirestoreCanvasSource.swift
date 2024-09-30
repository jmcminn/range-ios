import Foundation
import RealmSwift

/// Represents the ``CanvasSource`` (`projects/<id>/canvasSources/<id>` path in Firestore)
/// There's no support for encoding currently as it's a readonly data
struct FirestoreCanvasSource: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = CanvasSource

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case 
        canvasId = "canvas",
        center,
        isGeolocated,
        name,
        rotation,
        storageVersion,
        styleUrl,
        tilesetUrl,
        typeString = "type",
        userDefinedScale,
        zoom
    }

    var canvasId: String
    var center: LocationCoordinate2DCodable
    var isGeolocated: Bool?
    var name: String
    var rotation: Double?
    var storageVersion: [String: String]?
    var styleUrl: String?
    var tilesetUrl: String?
    var typeString: String
    var userDefinedScale: Double?
    var zoom: Double?

    func upsert(withId id: String, inRealm realm: Realm) throws {
        guard let type = CanvasSourceType(fromString: typeString) else {
            throw "CanvasSource type not supported: \(typeString)"
        }
        let canvas = realm.objectOrPlaceholder(ofType: Canvas.self, forPrimaryKey: canvasId)
        let canvasSource = CanvasSource(
            id: id,
            type: type,
            name: name,
            center: center.decodedCoordinates,
            rotation: rotation ?? 0.0,
            isGeolocated: isGeolocated ?? (type == .pdf ? false : true),
            userDefinedScale: userDefinedScale,
            mainStorageVersion: storageVersion?["main"],
            zoom: zoom,
            styleUrl: styleUrl,
            tilesetUrl: tilesetUrl
        )
        realm.add(canvasSource, update: .modified)
        canvas.canvasSources.insert(canvasSource)
    }
}
