import CoreLocation
import Foundation
import OSLog
import RealmSwift

/// Represents the `Collaboration` (`projects/collaboration` path in Firebase)
///
/// Encoded as:
///
///     {
///         "feature"    : "e5db7eb2-bd9f-44ba-9c90-e6e6e528b930",
///         "statusName" : "6403e6dd-52df-4f4b-bf06-167e53b27e7a",
///         "name"       : "name",
///         "description": "description"
///         "tags"       : // not implemented on iOS yet
///     }
struct FirebaseCollaboration: Codable, FirestoreToRealmSyncable {
    typealias ModelType = Collaboration

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case featureId = "feature", statusId = "statusName", name,
             collaborationDescription = "description", tagIds = "tags"
    }

    var featureId: String
    var statusId: String?
    var name: String
    var collaborationDescription: String
    var tagIds: [String]

    /// Default initializer with all properties
    init(
        featureId: String,
        statusId: String?,
        name: String,
        description: String,
        tagIds: [String]
    ) {
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
            featureId: featureId,
            statusId: statusId,
            name: collaboration.name,
            description: collaboration.collaborationDescription,
            tagIds: tagIds
        )
    }

    func upsertCommand(id: String) throws -> Command {
        AddCollaborationCommand(
            collaborationId: id,
            featureId: featureId,
            name: name,
            collaborationDescription: collaborationDescription,
            statusId: statusId,
            tagIds: tagIds
        )
    }
}
