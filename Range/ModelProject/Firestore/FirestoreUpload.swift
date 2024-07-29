
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
             correlationId = "correlation",
             createdById = "createdBy", createdAt,
             descriptionString = "description",
             fileSize,
             fileTypeString = "fileType",
             imageHeightToWidth,
             lastUpdatedAt,
             name,
             parentId = "parent", parentType,
             storageVersion,
             tagIds = "tags"
    }

    var annotations: String?
    var correlationId: String
    var createdById: String
    var createdAt: Date
    var descriptionString: String?
    var fileSize: Int64?
    var fileTypeString: String?
    var imageHeightToWidth: Double?
    var lastUpdatedAt: Date
    var name: String?
    var parentId: String
    var parentType: String
    var storageVersion: [String: String]?
    var tagIds: [String]

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
        let author = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: createdById)
        let upload = Upload(
            id: id,
            createdAt: createdAt,
            lastUpdatedAt: lastUpdatedAt,
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
