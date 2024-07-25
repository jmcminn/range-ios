
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
struct FirestoreUpload: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = Upload

    /// CodingKeys used by Codable as a keys in the encoded form
    enum CodingKeys: String, CodingKey, CaseIterable {
        case annotations,
             authorId = "author",
             correlationId = "correlation",
             descriptionString = "description",
             fileSize,
             fileTypeString = "fileType",
             imageHeightToWidth,
             name,
             parentId = "parent", parentType,
             storageVersion,
             tagIds = "tags",
             timestamp
    }

    var parentId: String
    var parentType: String
    var authorId: String
    var timestamp: Date
    var name: String?
    var descriptionString: String?
    var correlationId: String
    var tagIds: [String]
    var fileTypeString: String?
    var imageHeightToWidth: Double?
    var fileSize: Int64?
    var storageVersion: [String: String]?
    var annotations: String?

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

        let existingUpload = realm.object(ofType: Upload.self, forPrimaryKey: id)

        if let existingUpload = existingUpload {
            existingUpload.cleanupOldTags(newTagIds: tagIds)
        }

        // if the upload has local imageHeightToWidth then keep it
        var imageHeightToWidth = imageHeightToWidth
        if imageHeightToWidth == nil, let existingUpload = existingUpload {
            imageHeightToWidth = existingUpload.imageHeightToWidth
        }

        let collaboration = realm.objectOrPlaceholder(ofType: Collaboration.self, forPrimaryKey: parentId)
        let author = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: authorId)
        let upload = Upload(
            id: id,
            timestamp: timestamp,
            name: name,
            description: descriptionString,
            correlationId: correlationId,
            fileType: fileType,
            imageHeightToWidth: imageHeightToWidth,
            fileSize: fileSize,
            storageVersion: storageVersion,
            localStorageVersion: existingUpload?.localStorageVersion, // preserve the localStorageVersion
            annotations: annotations != nil ? Annotations(persistedValue: annotations!) : nil
        )
        upload.author = author
        realm.add(upload, update: .modified)
        collaboration.uploads.insert(upload)
        upload.tags.removeAll()
        upload.addNewTags(newTagIds: tagIds, realm: realm)
    }
}
