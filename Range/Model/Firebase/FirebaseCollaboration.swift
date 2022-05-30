import CoreLocation
import Foundation

/// Represents the `Collaboration` (`projects/details/collaboration` path in Firebase)
///
/// Encoded as:
///
///     {
///         "id"         : "0521fccf-3799-4786-aab1-e5e5108c0807",
///         "feature"    : "e5db7eb2-bd9f-44ba-9c90-e6e6e528b930",
///         "statusName" : "6403e6dd-52df-4f4b-bf06-167e53b27e7a",
///         "name"       : "name",
///         "description": "description"
///         "tags"       : // not implemented on iOS yet
///     }
struct FirebaseCollaboration: Codable {
    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case id, featureId = "feature", statusId = "statusName", name, collaborationDescription = "description"
    }

    let id: String
    let featureId: String
    let statusId: String
    let name: String
    let collaborationDescription: String

    /// decoded Collaboration
    var collaboration: Collaboration {
        Collaboration(id: id, name: name, description: collaborationDescription)
    }
}
