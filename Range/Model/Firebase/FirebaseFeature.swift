import CoreLocation
import Foundation
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

    /// Add or update the feature. It fails with warning only
    func upsert(_ realm: Realm) throws {
        guard let geometry = realm.object(ofType: Geometry.self, forPrimaryKey: geometryId) else {
            throw "geometry not found: \(geometryId)"
        }
        let feature = Feature(id: id, name: name)
        realm.add(feature, update: .modified)
        geometry.features.insert(feature)
    }
}
