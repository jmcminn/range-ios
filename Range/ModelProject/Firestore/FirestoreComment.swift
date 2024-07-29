
import CoreLocation
import FirebaseFirestore
import Foundation
import RealmSwift

/// Represents the `Comment` (`projects/comments` path in Firestore)
///
/// Encoded as:
///
///     {
///         "parent": "13083d62-03a1-43d7-8eb0-ca5bb8b357f3",
///         "parentType": "Collaboration",
///         "createdBy": "9e06df97-aa0f-4e0f-8c78-8892bfb126ec",
///         "createdAt": 1649228400000,
///         "text": "Starting on the polygon",
///         "isCompleted": false  // optional
///     }
struct FirestoreComment: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = Comment

    /// CodingKeys used by Codable as a keys in the encoded form
    enum CodingKeys: String, CodingKey, CaseIterable {
        case completedById = "completedBy", completedTimestamp,
             createdById = "createdBy", createdAt,
             isNote,
             lastUpdatedAt,
             parentId = "parent", parentType,
             text, textIsEdited
    }

    var completedById: String? // participant id
    var completedTimestamp: Date?
    var createdById: String
    var createdAt: Date
    var isNote: Bool? // if missing will default to false
    var lastUpdatedAt: Date
    var parentId: String
    var parentType: String
    var text: String
    var textIsEdited: Bool? // if missing will default to false

    func upsert(withId id: String, inRealm realm: RealmSwift.Realm) throws {
        guard parentType == "Collaboration" || parentType == "Upload" else {
            throw "parentType not supported: \(parentType)"
        }
        let author = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: createdById)
        let comment = Comment(
            id: id,
            createdAt: createdAt,
            lastUpdatedAt: lastUpdatedAt,
            text: text,
            textIsEdited: textIsEdited ?? false,
            isNote: isNote ?? false,
            completedTimestamp: completedTimestamp
        )
        comment.author = author
        if let completedById = completedById {
            comment.completedBy = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: completedById)
        }
        realm.add(comment, update: .modified)
        if parentType == "Collaboration" {
            let collaboration = realm.objectOrPlaceholder(ofType: Collaboration.self, forPrimaryKey: parentId)
            collaboration.comments.insert(comment)
        } else if parentType == "Upload" {
            let upload = realm.objectOrPlaceholder(ofType: Upload.self, forPrimaryKey: parentId)
            upload.comments.insert(comment)
        }
    }
}
