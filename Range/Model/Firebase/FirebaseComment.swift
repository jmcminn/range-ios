
import CoreLocation
import FirebaseFirestore
import Foundation
import RealmSwift

/// Represents the `Comment` (`projects/comments` path in Firebase)
///
/// Encoded as:
///
///     {
///         "parent": "13083d62-03a1-43d7-8eb0-ca5bb8b357f3",
///         "parentType": "Collaboration",
///         "author": "9e06df97-aa0f-4e0f-8c78-8892bfb126ec",
///         "timestamp": 1649228400000,
///         "text": "Starting on the polygon",
///         "isCompleted": false  // optional
///     }
struct FirebaseComment: Codable, FirestoreToRealmSyncable {
    typealias ModelType = Comment

    /// CodingKeys used by Codable as a keys in the encoded form
    enum CodingKeys: String, CodingKey {
        case parentId = "parent", parentType, authorId = "author", timestamp, text, textIsEdited,
             isNote, completedById = "completedBy", completedTimestamp
    }

    var parentId: String
    var parentType: String
    var authorId: String
    var timestamp: Timestamp
    var text: String
    var textIsEdited: Bool? // if missing will default to false
    var isNote: Bool? // if missing will default to false
    var completedById: String? // participant id
    var completedTimestamp: Timestamp?

    func upsertCommand(id: String) throws -> Command {
        guard parentType == "Collaboration" else {
            throw "parentType not supported: \(parentType)"
        }
        return AddCommentCommand(
            commentId: id,
            parentType: parentType,
            parentId: parentId,
            authorId: authorId,
            timestamp: timestamp.dateValue(),
            text: text,
            textIsEdited: textIsEdited ?? false,
            isNote: isNote ?? false,
            completedById: completedById,
            completedTimestamp: completedTimestamp?.dateValue()
        )
    }
}
