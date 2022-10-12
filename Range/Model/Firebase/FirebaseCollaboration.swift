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
    enum CodingKeys: String, CodingKey {
        case featureId = "feature", authorId = "author", timestamp, statusId = "statusName", name,
             collaborationDescription = "description", tagIds = "tags", assigneeId = "assignee",
             dueDateTimestamp
    }

    var featureId: String
    var authorId: String?
    var timestamp: Int? // milliseconds
    var statusId: String?
    var name: String
    var collaborationDescription: String?
    var tagIds: [String]
    var assigneeId: String?
    var dueDateTimestamp: Int? // milliseconds

    func upsertCommand(id: String) throws -> Command {
        AddCollaborationCommand(
            collaborationId: id,
            featureId: featureId,
            authorId: authorId,
            timestamp: timestamp != nil ? TimeInterval(timestamp!) / 1000.0 : nil,
            name: name,
            collaborationDescription: collaborationDescription,
            statusId: statusId,
            tagIds: tagIds,
            assigneeId: assigneeId,
            dueDateTimestamp: dueDateTimestamp != nil ? TimeInterval(dueDateTimestamp!) / 1000.0 : nil
        )
    }
}
