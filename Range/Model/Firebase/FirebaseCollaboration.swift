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
             collaborationDescription = "description", tagIds = "tags"
    }

    var featureId: String
    var authorId: String?
    var timestamp: Int? // milliseconds
    var statusId: String?
    var name: String
    var collaborationDescription: String?
    var tagIds: [String]

    func upsertCommand(id: String) throws -> Command {
        let timestampTimeInterval: TimeInterval?
        if let timestamp = timestamp {
            timestampTimeInterval = TimeInterval(timestamp) / 1000.0
        } else {
            timestampTimeInterval = nil
        }
        return AddCollaborationCommand(
            collaborationId: id,
            featureId: featureId,
            authorId: authorId,
            timestamp: timestampTimeInterval,
            name: name,
            collaborationDescription: collaborationDescription,
            statusId: statusId,
            tagIds: tagIds
        )
    }
}
