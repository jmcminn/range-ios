
import CoreLocation
import FirebaseFirestore
import Foundation
import RealmSwift

/// Represents the `Upload` (`projects/uploads` path in Firebase)
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
struct FirebaseUpload: Codable, FirestoreToRealmSyncable {
    typealias ModelType = Upload

    /// CodingKeys used by Codable as a keys in the encoded form
    enum CodingKeys: String, CodingKey {
        case parentId = "parent", parentType, authorId = "author", timestamp, name,
             uploadDescription = "description", correlationId = "correlation", tagIds = "tags",
             fileTypeString = "fileType", imageHeightToWidth
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

    func upsertCommand(id: String) throws -> Command {
        let fileType: Upload.FileType
        if let fileTypeString = fileTypeString {
            fileType = try Upload.FileType.allCases.first { $0.rawValue == fileTypeString }
                .or(error: ModelError.fileTypeNotSupported(fileTypeString))
        } else {
            fileType = .image
        }
        guard parentType == "Collaboration" else {
            throw "parentType not supported: \(parentType)"
        }
        return AddUploadCommand(
            uploadId: id,
            correlationId: correlationId,
            fileType: fileType,
            parentType: parentType,
            parentId: parentId,
            authorId: authorId,
            timestamp: timestamp.dateValue(),
            name: name,
            uploadDescription: uploadDescription,
            tagIds: tagIds,
            imageHeightToWidth: imageHeightToWidth
        )
    }
}
