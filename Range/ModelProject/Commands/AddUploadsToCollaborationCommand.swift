import FirebaseFirestore
import Foundation
import RealmSwift

/// Adds given uploads to given collaboration.
/// Creates tags if not existing yet.
/// Attach provided tags to all uploads.
struct AddUploadsToCollaborationCommand: Command, Codable, Equatable {
    var type: CommandType { .create } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { .init([collaborationId]) }

    // Define the CodingKeys to skip the type
//    private enum CodingKeys: String, CodingKey {
//        case authorId, collaborationId, tags, uploadDescription, uploads
//    }

    var authorId: String
    var collaborationId: String
    var tags: [CommandTag]
    var uploadDescription: String?
    var uploads: [CommandUpload]
    var correlationId: String?
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
            let localStorageVersion = Map<String, String>()
            // mark storage version that there is a local file, so the MediaKey for MediaCache can
            // be constructed properly
            // After the file is uploaded this will be replaced with the real storage version from
            // backend. Pending uploads wait for the Upload object to be created (fail while it's not there)
            // so it's guaranteed that this will be set BEFORE the real value.
            localStorageVersion.setMainToLocalFile(annotated: false, generation: $0.mediaKey.storageVersion)
            if let annotatedMediaKey = $0.annotatedMediaKey {
                localStorageVersion.setMainToLocalFile(annotated: true, generation: annotatedMediaKey.storageVersion)
            }
            let upload = Upload(
                id: $0.mediaKey.uploadId,
                timestamp: Date.now,
                name: $0.name,
                description: uploadDescription,
                correlationId: correlationId ?? $0.mediaKey.uploadId,
                fileType: $0.mediaKey.fileType,
                imageHeightToWidth: $0.imageHeightToWidth,
                fileSize: $0.fileSize,
                localStorageVersion: localStorageVersion,
                annotations: $0.annotations
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

/// Add pending uploads for all the media keys
extension AddUploadsToCollaborationCommand: PendingUploadCommand {
    func addPendingUploads(_ pendingUploadsModel: PendingUploadsModel) async throws {
        for upload in uploads {
            try await pendingUploadsModel.addPendingUpload(forKey: upload.mediaKey)
            if let annotatedMediaKey = upload.annotatedMediaKey {
                try await pendingUploadsModel.addPendingUpload(forKey: annotatedMediaKey)
            }
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
        let newUploads = try uploads.filter { try !ctx.exists(.upload($0.mediaKey.uploadId)) }

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
                correlationId: correlationId ?? $0.mediaKey.uploadId,
                tagIds: tagIds,
                fileTypeString: $0.mediaKey.fileType.rawValue,
                imageHeightToWidth: $0.imageHeightToWidth,
                fileSize: $0.fileSize,
                annotations: $0.annotations?.persistableValue
            )
            var data = try Firestore.Encoder().encode(firestoreObject)
            data[FirestoreUpdate.CodingKeys.timestamp.rawValue] = FieldValue.serverTimestamp()
            ctx.setData(data, forDocument: .upload($0.mediaKey.uploadId))
        }
    }
}
