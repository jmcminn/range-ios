import CoreLocation
import Foundation
import OSLog
import RealmSwift

/// Represents the `Feature` (`projects/details/features` path in Firebase)
///
/// Encoded as:
///
///     {
///         "id"       : "0521fccf-3799-4786-aab1-e5e5108c0807",
///         "geometry" : "e5db7eb2-bd9f-44ba-9c90-e6e6e528b930",
///         "name"     : "name",
///         "description": "..."  // optional, not implemented on iOS
///     }
struct FirebaseFeature: Codable, FirebaseToRealmSyncable {
    typealias ModelType = Feature

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case id, geometryId = "geometry", name
    }

    var id: String
    var geometryId: String
    var name: String

    /// For constructing with all properties
    init(id: String, geometryId: String, name: String) {
        self.id = id
        self.geometryId = geometryId
        self.name = name
    }

    /// For constructing from the `Feature` object
    /// geometryId is passed here and not taken from the Feature as it is kind of optional in the Feature and it is required here
    init(geometryId: String, feature: Feature) {
        self.init(id: feature.id, geometryId: geometryId, name: feature.name)
    }

    /// Add or update the feature. It fails with warning only
    func upsert(_ realm: Realm) throws {
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
