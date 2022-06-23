
import CoreLocation
import Foundation
import RealmSwift

/// Represents the `Upload` (`projects/details/uploads` path in Firebase)
///
/// Encoded as:
///
///     {
///         "id":  "6ebe0ded-414b-4a5e-be09-5d079d5dd7dc",
///         "parent": "0ab55565-baf2-4361-8177-dfd4edfe343c",
///         "parentType": "Collaboration",
///         "author": "718d800c-0174-4128-9c5b-6e47a76d3c0e",
///         "timestamp": 1653982892906,
///         "name": "", j
///         "description": "",
///         "url": "http....",
///         "correlation": "6ebe0ded-414b-4a5e-be09-5d079d5dd7dc"
///     }
struct FirebaseUpload: Codable, FirebaseToRealmSyncable {
    typealias ModelType = Upload

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case id, parentId = "parent", parentType, authorId = "author", timestamp, name,
             uploadDescription = "description", urlString = "url", correlationId = "correlation"
    }

    var id: String
    var parentId: String
    var parentType: String
    var authorId: String
    var timestamp: Int
    var name: String
    var uploadDescription: String
    var urlString: String
    var correlationId: String

    /// Add or update the upload and add it to appropriate parent (based on parentType). Also sets the author. Fails if parent or author not found
    func upsert(_ realm: Realm) throws {
        guard parentType == "Collaboration" else {
            throw "parentType not supported: \(parentType)"
        }
        guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: parentId) else {
            throw "collaboration not found: \(parentId)"
        }
        guard let author = realm.object(ofType: Participant.self, forPrimaryKey: authorId) else {
            throw "author not found: \(authorId)"
        }
        guard let url = URL(string: urlString) else {
            throw "malformed url: \(urlString)"
        }
        let upload = Upload(
            id: id,
            timestamp: TimeInterval(timestamp),
            url: url,
            name: name,
            description: uploadDescription
        )
        // TODO: 44 add tags for upload, and update tag.uploads when upserting
        upload.author = author
        realm.add(upload, update: .modified)
        collaboration.uploads.insert(upload)
    }
}
