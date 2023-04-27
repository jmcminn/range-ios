import FirebaseFirestore
import Foundation
import RealmSwift

/// Update tags for given Upload(s)
struct UpdateUploadsTagsCommand: Command, Codable, Equatable {
    let uploadIds: [String]
    var tags: [CommandTag]
    // should it add given tags to uploads (true) or replace (false). Replace is the default behavior
    var add: Bool = false
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
            if !add {
                // only remove previous tags if replacing (not adding)
                upload.cleanupOldTags(newTagIds: tagIds)
                upload.tags.removeAll()
            }
            upload.addNewTags(newTagIds: tagIds, realm: realm)
        }
    }
}

/// Apply the `Upload.tags` update in Firestore.
extension UpdateUploadsTagsCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise abort (the command cannot be applied)
        let uploadsToUpdate = try uploadIds.compactMap { uploadId in
            if let upload = try ctx.getDocument(.upload(uploadId), as: FirestoreUpload.self) {
                // return a pair of (id, upload) as FirestoreUpload doesn't contain the id
                return (uploadId, upload)
            } else {
                return nil
            }
        }
        if !uploadIds.isEmpty, uploadsToUpdate.isEmpty {
            throw FirestoreCommandError.obsolete("upload doesn't exist")
        }

        // only add new tags... don't touch the existing ones
        let newTags = try tags.filter { try !ctx.exists(.tagName($0.id)) }

        // ------------- WRITES ----------------
        try newTags.forEach {
            try ctx.setData(from: $0.asFirestoreTagName, forDocument: .tagName($0.id))
        }
        let tagIds = tags.map(\.id)
        for (uploadId, upload) in uploadsToUpdate {
            let updatedTagIds: [String]
            if add {
                // keep the uploads tag ids and add *new tags only*
                var newTagIds = upload.tagIds
                for tagId in tagIds {
                    if !newTagIds.contains(tagId) {
                        newTagIds.append(tagId)
                    }
                }
                updatedTagIds = newTagIds
            } else {
                // just replace with given tag ids
                updatedTagIds = tagIds
            }
            ctx.updateData(
                [FirestoreUpload.CodingKeys.tagIds.rawValue: updatedTagIds],
                forDocument: .upload(uploadId)
            )
        }
    }
}
