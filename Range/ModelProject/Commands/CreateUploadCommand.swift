import FirebaseFirestore
import Foundation
import RealmSwift

/// Creates an upload and adds it to given collaboration.
/// Creates tags if not existing yet.
struct CreateUploadCommand: Command, Codable, Equatable {
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
    var upload: CommandUpload
    var correlationId: String?
}

/// Creates/updates the tags, creates the Upload and links with Collaboration
extension CreateUploadCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        let collaboration = try realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId)
            .or(error: ModelError.collaborationNotFound)
        let author = try realm.object(ofType: Participant.self, forPrimaryKey: authorId)
            .or(error: ModelError.userNotFound)
        // add or update tags
        let tags = tags.map(\.asTag)
        tags.forEach { realm.add($0, update: .modified) }

        let localStorageVersion = Map<String, String>()
        // mark storage version that there is a local file, so the MediaKey for MediaCache can
        // be constructed properly
        // After the file is uploaded this will be replaced with the real storage version from
        // backend. Pending uploads wait for the Upload object to be created (fail while it's not there)
        // so it's guaranteed that this will be set BEFORE the real value.
        localStorageVersion.setMainToLocalFile(annotated: false, generation: upload.mediaKey.storageVersion)
        if let annotatedMediaKey = upload.annotatedMediaKey {
            localStorageVersion.setMainToLocalFile(annotated: true, generation: annotatedMediaKey.storageVersion)
        }
        let realmUpload = Upload(
            id: upload.mediaKey.uploadId,
            timestamp: Date.now,
            name: upload.name,
            description: uploadDescription,
            correlationId: correlationId ?? upload.mediaKey.uploadId,
            fileType: upload.mediaKey.fileType,
            imageHeightToWidth: upload.imageHeightToWidth,
            fileSize: upload.fileSize,
            localStorageVersion: localStorageVersion,
            annotations: upload.annotations
        )
        realmUpload.author = author
        // add new upload
        realm.add(realmUpload, update: .error)
        realmUpload.tags.append(objectsIn: tags)
        tags.forEach { t in t.uploads.insert(realmUpload) }
        collaboration.uploads.insert(realmUpload)
    }
}

/// Add pending uploads for all the media keys
extension CreateUploadCommand: PendingUploadCommand {
    func addPendingUploads(_ pendingUploadsModel: PendingUploadsModel) async throws {
        try await pendingUploadsModel.addPendingUpload(forKey: upload.mediaKey)
        if let annotatedMediaKey = upload.annotatedMediaKey {
            try await pendingUploadsModel.addPendingUpload(forKey: annotatedMediaKey)
        }
    }
}

/// Provide data for the firebase function call
extension CreateUploadCommand: FirebaseFunctionCommand {
    var functionName: String { "createUpload" }

    func functionData(_ projectId: String) -> Any? {
        [
            "projectId": projectId,
            "collaborationId": collaborationId,
            "uploadId": upload.mediaKey.uploadId,
            "fileType": upload.mediaKey.fileType.rawValue,
            "fileSize": upload.fileSize,
            "imageHeightToWidth": upload.imageHeightToWidth,
            "correlationId": correlationId ?? upload.mediaKey.uploadId,
            "name": upload.name,
            "description": uploadDescription,
            "tags": tags.map { ["id": $0.id, "name": $0.name] },
            "annotations": upload.annotations?.persistableValue
        ]
    }
}
