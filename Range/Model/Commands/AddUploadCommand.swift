import Foundation
import RealmSwift

/// Add or update the `Upload`.
struct AddUploadCommand: Command, Equatable {
    let uploadId: String
    var correlationId: String
    var fileType: Upload.FileType
    var parentType: String
    var parentId: String
    var authorId: String
    var timestamp: TimeInterval
    var name: String?
    var uploadDescription: String?
    var url: URL?
    var tagIds: [String]

    func apply(inRealm realm: Realm) throws {
        // remove the upload from the tags it was attached to and is not anymore
        if let existingObject = realm.object(ofType: Upload.self, forPrimaryKey: uploadId) {
            // for fast lookup
            let tagIdsSet = Set(tagIds)
            for tag in existingObject.tags {
                if !tagIdsSet.contains(tag.id) {
                    // updated tags don't contain this tag, remove the object from it
                    tag.uploads.remove(existingObject)
                }
            }
        }

        let collaboration = realm.objectOrPlaceholder(ofType: Collaboration.self, forPrimaryKey: parentId)
        let author = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: authorId)
        let upload = Upload(
            id: uploadId,
            timestamp: timestamp,
            url: url,
            name: name,
            description: uploadDescription,
            correlationId: correlationId,
            fileType: fileType
        )
        // if the upload has local height2Width then keep it
        if let existingUpload = realm.object(ofType: Upload.self, forPrimaryKey: uploadId) {
            upload.imageHeightToWidth = existingUpload.imageHeightToWidth
        }
        upload.author = author
        realm.add(upload, update: .modified)
        let tags = tagIds.compactMap { realm.objectOrPlaceholder(ofType: Tag.self, forPrimaryKey: $0) }
        upload.tags.append(objectsIn: tags)
        tags.forEach { $0.uploads.insert(upload) }
        collaboration.uploads.insert(upload)
    }
}
