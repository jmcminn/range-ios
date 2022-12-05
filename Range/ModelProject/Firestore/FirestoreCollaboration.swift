import CoreLocation
import FirebaseFirestore
import Foundation
import OSLog
import RealmSwift

/// Represents the `Collaboration` (`projects/collaboration` path in Firestore)
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
struct FirestoreCollaboration: Codable, FirestoreToRealmSyncable {
    typealias ModelType = Collaboration

    /// CodingKeys used by Codable as a keys in the encoded form
    enum CodingKeys: String, CodingKey {
        case featureId = "feature", authorId = "author", timestamp, statusId = "statusName", name,
             collaborationDescription = "description", tagIds = "tags", assigneeId = "assignee",
             dueDateTimestamp
    }

    var featureId: String
    var authorId: String?
    var timestamp: Timestamp
    var statusId: String?
    var name: String
    var collaborationDescription: String?
    var tagIds: [String]
    var assigneeId: String?
    var dueDateTimestamp: Timestamp?

    func upsert(withId id: String, inRealm realm: Realm) throws {
        if let existingCollaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: id) {
            existingCollaboration.cleanupOldTags(newTagIds: tagIds)
        }

        let feature = realm.objectOrPlaceholder(ofType: Feature.self, forPrimaryKey: featureId)
        let collaboration = Collaboration(
            id: id,
            timestamp: timestamp.dateValue(),
            name: name,
            description: collaborationDescription,
            dueDateTimestamp: dueDateTimestamp?.dateValue()
        )
        if let authorId = authorId {
            collaboration.author = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: authorId)
        }
        if let statusId = statusId {
            collaboration.status = realm.objectOrPlaceholder(ofType: Status.self, forPrimaryKey: statusId)
        }
        if let assigneeId = assigneeId {
            collaboration.assignee = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: assigneeId)
        }
        realm.add(collaboration, update: .modified)
        collaboration.tags.removeAll()
        collaboration.addNewTags(newTagIds: tagIds, realm: realm)
        feature.collaborations.insert(collaboration)
    }
}
