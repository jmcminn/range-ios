import CoreLocation
import Foundation
import RealmSwift

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
struct FirebaseCollaboration: Codable, FirebaseToRealmSyncable {
    typealias ModelType = Collaboration

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case id, featureId = "feature", statusId = "statusName", name,
             collaborationDescription = "description", tagIds = "tags"
    }

    var id: String
    var featureId: String
    var statusId: String
    var name: String
    var collaborationDescription: String
    var tagIds: [String]

    /// Add or update the collaboration and add it to the feature. Also sets the status. Fails if feature or status not found
    func upsert(_ realm: Realm) throws {
        guard let feature = realm.object(ofType: Feature.self, forPrimaryKey: featureId) else {
            throw "feature not found: \(featureId)"
        }
        guard let status = realm.object(ofType: Status.self, forPrimaryKey: statusId) else {
            throw "status not found: \(statusId)"
        }
        let collaboration = Collaboration(id: id, name: name, description: collaborationDescription)
        collaboration.status = status
        collaboration.tags.removeAll()
        let tags = tagIds.compactMap { realm.object(ofType: Tag.self, forPrimaryKey: $0) }
        collaboration.tags.append(objectsIn: tags)
        realm.add(collaboration, update: .modified)
        tags.forEach { $0.collaborations.insert(collaboration) }
        feature.collaborations.insert(collaboration)
    }
}
