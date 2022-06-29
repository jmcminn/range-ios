import CoreLocation
import Foundation
import OSLog
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
    var statusId: String?
    var name: String
    var collaborationDescription: String
    var tagIds: [String]?

    /// Default initializer with all properties
    init(
        id: String,
        featureId: String,
        statusId: String?,
        name: String,
        description: String,
        tagIds: [String]
    ) {
        self.id = id
        self.featureId = featureId
        self.statusId = statusId
        self.name = name
        collaborationDescription = description
        self.tagIds = tagIds
    }

    /// For constructing from `Collaboration`.
    /// featureId is passed here and not taken from the Collaboration as it is kind of optional in the Collaboration and it is required here
    init(featureId: String, collaboration: Collaboration) {
        let statusId = collaboration.status?.id
        let tagIds = Array(collaboration.tags.map(\.id))
        self.init(
            id: collaboration.id,
            featureId: featureId,
            statusId: statusId,
            name: collaboration.name,
            description: collaboration.collaborationDescription,
            tagIds: tagIds
        )
    }

    /// Add or update the collaboration and add it to the feature. Also sets the status. Fails if feature or status not found
    func upsert(_ realm: Realm) throws {
        let feature: Feature
        if let f = realm.object(ofType: Feature.self, forPrimaryKey: featureId) {
            feature = f
        } else {
            Logger.firestore
                .debug(
                    "Feature not found for collaboration \(id, privacy: .public), creating a placeholder \(featureId, privacy: .public)"
                )
            feature = Feature(placeholder: featureId)
            realm.add(feature)
        }
//        guard let feature = realm.object(ofType: Feature.self, forPrimaryKey: featureId) else {
//            throw "feature not found: \(featureId)"
//        }
        let collaboration = Collaboration(id: id, name: name, description: collaborationDescription)
        // TODO: 44 support placeholders for statuses
        if let statusId = statusId {
            guard let status = realm.object(ofType: Status.self, forPrimaryKey: statusId) else {
                throw "status not found: \(statusId)"
            }
            collaboration.status = status
        }
        collaboration.tags.removeAll()
        realm.add(collaboration, update: .modified)
        if let tagIds = tagIds {
            // TODO: 44 support placeholders for tags
            let tags = tagIds.compactMap { realm.object(ofType: Tag.self, forPrimaryKey: $0) }
            collaboration.tags.append(objectsIn: tags)
            // TODO: 44 remove the collaboration from the tags it was attached to and is not anymore
            tags.forEach { $0.collaborations.insert(collaboration) }
        }
        feature.collaborations.insert(collaboration)
    }
}
