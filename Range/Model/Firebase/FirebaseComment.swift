
import CoreLocation
import Foundation
import RealmSwift

/// Represents the `Comment` (`projects/details/comments` path in Firebase)
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
struct FirebaseComment: Codable, FirebaseToRealmSyncable {
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

    /// Add or update the comment and add it to appropriate parent (based on parentType). Also sets the authr. Fails if parent or author not found
    func upsert(_ realm: Realm, id: String) throws {
        guard parentType == "Collaboration" else {
            throw "parentType not supported: \(parentType)"
        }
        guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: parentId) else {
            throw "collaboration not found: \(parentId)"
        }
        guard let author = realm.object(ofType: Participant.self, forPrimaryKey: authorId) else {
            throw "author not found: \(authorId)"
        }
        let comment = Comment(id: id, timestamp: TimeInterval(timestamp), text: text, isCompleted: isCompleted)
        comment.author = author
        realm.add(comment, update: .modified)
        collaboration.comments.insert(comment)
    }
}
