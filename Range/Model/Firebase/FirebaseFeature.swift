import CoreLocation
import Foundation
import OSLog
import RealmSwift

/// Represents the `Feature` (`projects/features` path in Firebase)
///
/// Encoded as:
///
///     {
///         "geometry" : "e5db7eb2-bd9f-44ba-9c90-e6e6e528b930",
///         "name"     : "name",
///         "description": "..."  // optional, not implemented on iOS
///     }
struct FirebaseFeature: Codable, FirestoreToRealmSyncable {
    typealias ModelType = Feature

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case geometryId = "geometry", name, featureDescription = "description"
    }

    var geometryId: String
    var name: String
    var featureDescription: String?

    /// For constructing with all properties
    init(geometryId: String, name: String, description: String?) {
        self.geometryId = geometryId
        self.name = name
        featureDescription = description
    }

    /// For constructing from the `Feature` object
    /// geometryId is passed here and not taken from the Feature as it is kind of optional in the Feature and it is required here
    init(geometryId: String, feature: Feature) {
        self.init(geometryId: geometryId, name: feature.name, description: feature.featureDescription)
    }

    func upsert(withId id: String, inRealm realm: RealmSwift.Realm) throws {
        let geometry = realm.objectOrPlaceholder(ofType: Geometry.self, forPrimaryKey: geometryId)
        let feature = Feature(id: id, name: name, description: featureDescription)
        realm.add(feature, update: .modified)
        geometry.features.insert(feature)
    }
}
