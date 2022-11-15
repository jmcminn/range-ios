import FirebaseFirestore
import Foundation
import RealmSwift

/// Update tags for given Upload
struct UpdateUploadTagsCommand: Command, Codable, Equatable {
    let uploadId: String
    var tags: [CommandTag]
}

extension UpdateUploadTagsCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let upload = realm.object(ofType: Upload.self, forPrimaryKey: uploadId) else {
            throw ModelError.uploadNotFound
        }
        // add or update tags
        let tags = tags.map(\.asTag)
        tags.forEach { realm.add($0, update: .modified) }

        // update tags <-> upload
        let tagIds = tags.map(\.id)
        UpsertUploadCommand.cleanupOldTags(upload: upload, newTagIds: tagIds)
        upload.tags.removeAll()
        UpsertUploadCommand.addNewTags(upload: upload, newTagIds: tagIds, realm: realm)
    }
}

/// Apply the `Upload.tags` update in Firestore.
extension UpdateUploadTagsCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise abort (the command cannot be applied)
        guard try ctx.exists(.upload(uploadId)) else {
            throw FirestoreCommandError.obsolete("upload doesn't exist")
        }
        // only add new tags... don't touch the existing ones
        let newTags = try tags.filter { try !ctx.exists(.tagName($0.id)) }

        // ------------- WRITES ----------------
        try newTags.forEach {
            try ctx.setData(from: $0.asFirestoreTagName, forDocument: .tagName($0.id))
        }
        let tagIds = tags.map(\.id)
        ctx.updateData(
            [FirebaseUpload.CodingKeys.tagIds.rawValue: tagIds],
            forDocument: .upload(uploadId)
        )
    }
}
