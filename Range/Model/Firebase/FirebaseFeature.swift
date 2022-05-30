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
        case id, geometryId = "geometry", name
    }

    let id: String
    let geometryId: String
    let name: String

    /// decoded Feature
    var feature: Feature {
        Feature(id: id, name: name)
    }
}
