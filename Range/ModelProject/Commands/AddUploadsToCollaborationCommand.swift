import FirebaseFirestore
import Foundation
import RealmSwift

/// Adds given uploads to given collaboration.
/// Creates tags if not existing yet.
/// Attach provided tags to all uploads.
struct AddUploadsToCollaborationCommand: Command, Codable, Equatable {
    var authorId: String
    var collaborationId: String
    var tags: [CommandTag]
    var uploadDescription: String?
    var uploads: [CommandUpload]
}

/// Creates/updates the tags, creates the Uploads and links with Collaboration
extension AddUploadsToCollaborationCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        let collaboration = try realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId)
            .or(error: ModelError.collaborationNotFound)
        let author = try realm.object(ofType: Participant.self, forPrimaryKey: authorId)
            .or(error: ModelError.userNotFound)
        // add or update tags
        let tags = tags.map(\.asTag)
        tags.forEach { realm.add($0, update: .modified) }

        uploads.forEach {
            let upload = Upload(
                id: $0.id,
                timestamp: Date.now,
                name: $0.name,
                description: uploadDescription,
                correlationId: $0.id,
                fileType: $0.fileType,
                imageHeightToWidth: $0.imageHeightToWidth,
                fileSize: $0.fileSize
            )
            upload.author = author
            // add new upload
            realm.add(upload, update: .error)
            upload.tags.append(objectsIn: tags)
            tags.forEach { t in t.uploads.insert(upload) }
            collaboration.uploads.insert(upload)
        }
    }
}

/// Creates new Uploads in Firestore and adds to given collaboration.
/// Creates the tags that don't exist yet.
/// This command is idempotent in a way that it checks if given uploads/tags are already created, if so it doesn't recreate or update them.
/// It fails with the "obsolete" error if collaboration or author doesn't exist. This means that either of them was already removed
/// and this command should be aborted and not attempted again.
extension AddUploadsToCollaborationCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that collaboration and author exist, otherwise abort (the command cannot be applied)
        guard try ctx.exists(.collaboration(collaborationId)) else {
            throw FirestoreCommandError.obsolete("collaboration doesn't exist")
        }
        guard try ctx.exists(.participant(authorId)) else {
            throw FirestoreCommandError.obsolete("user doesn't exist")
        }

        // only add new tags... don't touch the existing ones
        let newTags = try tags.filter { try !ctx.exists(.tagName($0.id)) }

        // make it idempotent, only upload if not uploaded yet (this check is too granular, as
        // if any upload is there it means all are there but still it's correct)
        let newUploads = try uploads.filter { try !ctx.exists(.upload($0.id)) }

        // ------------- WRITES ----------------
        try newTags.forEach {
            try ctx.setData(from: $0.asFirestoreTagName, forDocument: .tagName($0.id))
        }

        let tagIds = tags.map(\.id)
        // add uploads
        try newUploads.forEach {
            let firestoreObject = FirestoreUpload(
                parentId: collaborationId,
                parentType: "Collaboration",
                authorId: authorId,
                timestamp: Timestamp(), // doesn't matter, updated to server timestamp after encoding
                name: $0.name,
                uploadDescription: uploadDescription,
                correlationId: $0.id,
                tagIds: tagIds,
                fileTypeString: $0.fileType.rawValue,
                imageHeightToWidth: $0.imageHeightToWidth,
                fileSize: $0.fileSize
            )
            var data = try Firestore.Encoder().encode(firestoreObject)
            data[FirestoreUpdate.CodingKeys.timestamp.rawValue] = FieldValue.serverTimestamp()
            ctx.setData(data, forDocument: .upload($0.id))
        }
    }
}
