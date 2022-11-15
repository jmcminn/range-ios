import Foundation
import RealmSwift

/// Add or update the `Upload` in local Realm db.
struct UpsertUploadCommand: LocalCommand, Equatable {
    let uploadId: String
    var correlationId: String
    var fileType: Upload.FileType
    var parentType: String
    var parentId: String
    var authorId: String
    var timestamp: Date
    var name: String?
    var uploadDescription: String?
    var tagIds: [String]
    var imageHeightToWidth: Double?

    /// remove the upload from the tags it was attached to and is not anymore
    static func cleanupOldTags(upload: Upload, newTagIds: [String]) {
        // for fast lookup
        let tagIdsSet = Set(newTagIds)
        for tag in upload.tags {
            if !tagIdsSet.contains(tag.id) {
                // updated tags don't contain this tag, remove the upload from it
                tag.uploads.remove(upload)
            }
        }
    }

    /// Add given tags to upload and also link the Upload in Tags
    static func addNewTags(upload: Upload, newTagIds: [String], realm: Realm) {
        let tags = newTagIds.uniqued().compactMap { realm.objectOrPlaceholder(ofType: Tag.self, forPrimaryKey: $0) }
        upload.tags.append(objectsIn: tags)
        tags.forEach { $0.uploads.insert(upload) }
    }

    func apply(inRealm realm: Realm) throws {
        if let existingObject = realm.object(ofType: Upload.self, forPrimaryKey: uploadId) {
            UpsertUploadCommand.cleanupOldTags(upload: existingObject, newTagIds: tagIds)
        }

        let collaboration = realm.objectOrPlaceholder(ofType: Collaboration.self, forPrimaryKey: parentId)
        let author = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: authorId)
        let upload = Upload(
            id: uploadId,
            timestamp: timestamp,
            name: name,
            description: uploadDescription,
            correlationId: correlationId,
            fileType: fileType,
            imageHeightToWidth: imageHeightToWidth
        )
        upload.author = author
        realm.add(upload, update: .modified)
        collaboration.uploads.insert(upload)
        upload.tags.removeAll()
        UpsertUploadCommand.addNewTags(upload: upload, newTagIds: tagIds, realm: realm)
    }
}
