import FirebaseFirestore
import Foundation
import RealmSwift

/// Update tags for given Upload(s)
struct UpdateUploadsTagsCommand: Command, Codable, Equatable {
    let uploadIds: [String]
    var tags: [CommandTag]
}

extension UpdateUploadsTagsCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        var uploadsToUpdate = [Upload]()
        for uploadId in uploadIds {
            // fail locally if any of the uploads doesn't exist, this shouldn't really happen
            guard let upload = realm.object(ofType: Upload.self, forPrimaryKey: uploadId) else {
                throw ModelError.uploadNotFound
            }
            uploadsToUpdate.append(upload)
        }
        // add or update tags
        let tags = tags.map(\.asTag)
        tags.forEach { realm.add($0, update: .modified) }

        // update tags <-> upload
        let tagIds = tags.map(\.id)
        for upload in uploadsToUpdate {
            upload.cleanupOldTags(newTagIds: tagIds)
            upload.tags.removeAll()
            upload.addNewTags(newTagIds: tagIds, realm: realm)
        }
    }
}

/// Apply the `Upload.tags` update in Firestore.
extension UpdateUploadsTagsCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise abort (the command cannot be applied)
        let uploadIdsToUpdate = try uploadIds.filter { try ctx.exists(.upload($0)) }
        if !uploadIds.isEmpty, uploadIdsToUpdate.isEmpty {
            throw FirestoreCommandError.obsolete("upload doesn't exist")
        }

        // only add new tags... don't touch the existing ones
        let newTags = try tags.filter { try !ctx.exists(.tagName($0.id)) }

        // ------------- WRITES ----------------
        try newTags.forEach {
            try ctx.setData(from: $0.asFirestoreTagName, forDocument: .tagName($0.id))
        }
        let tagIds = tags.map(\.id)
        for uploadId in uploadIdsToUpdate {
            ctx.updateData(
                [FirestoreUpload.CodingKeys.tagIds.rawValue: tagIds],
                forDocument: .upload(uploadId)
            )
        }
    }
}
