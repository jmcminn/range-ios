import CoreLocation
import Foundation

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
struct FirebaseFeature: Codable {
    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case id
        case geometry
        case name
    }

    /// UUID identifier of the parent
    let geometryId: String
    /// decodes into Range Feature
    let feature: Feature

    /// Constructor taking the geometry
    init(geometryId: String, feature: Feature) {
        self.geometryId = geometryId
        self.feature = feature
    }

    /// Custom implementation of decoding that handles different geometry types
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        geometryId = try container.decode(String.self, forKey: .geometry)
        let name = try container.decode(String.self, forKey: .name)
        feature = Feature(id: id, name: name)
    }

    /// Custom implementation of encoding that handles different geometry types
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(feature.id, forKey: .id)
        try container.encode(geometryId, forKey: .geometry)
        try container.encode(feature.name, forKey: .name)
    }
}
