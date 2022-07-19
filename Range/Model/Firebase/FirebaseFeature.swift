import CoreLocation
import Foundation
import OSLog
import RealmSwift

/// Represents the `Feature` (`projects/details/features` path in Firebase)
///
/// Encoded as:
///
///     {
///         "geometry" : "e5db7eb2-bd9f-44ba-9c90-e6e6e528b930",
///         "name"     : "name",
///         "description": "..."  // optional, not implemented on iOS
///     }
struct FirebaseFeature: Codable, FirebaseToRealmSyncable {
    typealias ModelType = Feature

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case geometryId = "geometry", name
    }

    var geometryId: String
    var name: String

    /// For constructing with all properties
    init(geometryId: String, name: String) {
        self.geometryId = geometryId
        self.name = name
    }

    /// For constructing from the `Feature` object
    /// geometryId is passed here and not taken from the Feature as it is kind of optional in the Feature and it is required here
    init(geometryId: String, feature: Feature) {
        self.init(geometryId: geometryId, name: feature.name)
    }

    /// Add or update the feature. It fails with warning only
    func upsert(_ realm: Realm, id: String) throws {
        let geometry: Geometry
        if let g = realm.object(ofType: Geometry.self, forPrimaryKey: geometryId) {
            geometry = g
        } else {
            Logger.firestore
                .debug(
                    "Geometry not found for feature \(id, privacy: .public), creating a placeholder \(geometryId, privacy: .public)"
                )
            geometry = Geometry(placeholder: geometryId)
            realm.add(geometry)
        }
        let feature = Feature(id: id, name: name)
        realm.add(feature, update: .modified)
        geometry.features.insert(feature)
    }
}
