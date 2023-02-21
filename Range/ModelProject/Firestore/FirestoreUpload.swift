
import CoreLocation
import FirebaseFirestore
import Foundation
import RealmSwift

/// Represents the `Upload` (`projects/uploads` path in Firestore)
///
/// Encoded as:
///
///     {
///         "parent": "0ab55565-baf2-4361-8177-dfd4edfe343c",
///         "parentType": "Collaboration",
///         "author": "718d800c-0174-4128-9c5b-6e47a76d3c0e",
///         "timestamp": 1653982892906,
///         "name": "", j
///         "description": "",
///         "correlation": "6ebe0ded-414b-4a5e-be09-5d079d5dd7dc"
///     }
struct FirestoreUpload: Codable, FirestoreToRealmSyncable {
    typealias ModelType = Upload

    /// CodingKeys used by Codable as a keys in the encoded form
    enum CodingKeys: String, CodingKey {
        case parentId = "parent", parentType, authorId = "author", timestamp, name,
             uploadDescription = "description", correlationId = "correlation", tagIds = "tags",
             fileTypeString = "fileType", imageHeightToWidth, storageVersion
    }

    var parentId: String
    var parentType: String
    var authorId: String
    var timestamp: Timestamp
    var name: String?
    var uploadDescription: String?
    var correlationId: String
    var tagIds: [String]
    var fileTypeString: String?
    var imageHeightToWidth: Double?
    var storageVersion: [String: String]?

    func upsert(withId id: String, inRealm realm: Realm) throws {
        let fileType: Upload.FileType
        if let fileTypeString = fileTypeString {
            // backward compatibility
            if fileTypeString == "image" {
                fileType = .jpeg
            } else {
                fileType = try Upload.FileType(fromExtension: fileTypeString)
                    .or(error: ModelError.fileTypeNotSupported(fileTypeString))
            }
        } else {
            fileType = .jpeg
        }
        guard parentType == "Collaboration" else {
            throw "parentType not supported: \(parentType)"
        }

        if let existingObject = realm.object(ofType: Upload.self, forPrimaryKey: id) {
            existingObject.cleanupOldTags(newTagIds: tagIds)
        }

        let collaboration = realm.objectOrPlaceholder(ofType: Collaboration.self, forPrimaryKey: parentId)
        let author = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: authorId)
        let upload = Upload(
            id: id,
            timestamp: timestamp.dateValue(),
            name: name,
            description: uploadDescription,
            correlationId: correlationId,
            fileType: fileType,
            imageHeightToWidth: imageHeightToWidth,
            storageVersion: storageVersion
        )
        upload.author = author
        realm.add(upload, update: .modified)
        collaboration.uploads.insert(upload)
        upload.tags.removeAll()
        upload.addNewTags(newTagIds: tagIds, realm: realm)
    }
}
