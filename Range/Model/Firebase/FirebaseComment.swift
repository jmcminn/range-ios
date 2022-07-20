
import CoreLocation
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
    private enum CodingKeys: String, CodingKey {
        case parentId = "parent", parentType, authorId = "author", timestamp, text, isCompleted
    }

    var parentId: String
    var parentType: String
    var authorId: String
    var timestamp: Int
    var text: String
    var isCompleted: Bool?

    func upsertCommand(id: String) throws -> Command {
        guard parentType == "Collaboration" else {
            throw "parentType not supported: \(parentType)"
        }
        return AddCommentCommand(
            commentId: id,
            parentType: parentType,
            parentId: parentId,
            authorId: authorId,
            timestamp: TimeInterval(timestamp),
            text: text,
            isCompleted: isCompleted
        )
    }
}
