import FirebaseFirestore
import Foundation
import RealmSwift

/// Update annotations for given Upload
struct UpdateUploadAnnotationsCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { .init([uploadId]) }

    let uploadId: String
    var annotations: Annotations?
    let mediaKey: MediaKey
}

extension UpdateUploadAnnotationsCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let upload = realm.object(ofType: Upload.self, forPrimaryKey: uploadId) else {
            throw ModelError.uploadNotFound
        }
        upload.annotations = annotations
    }
}

/// Add pending upload for the media key
extension UpdateUploadAnnotationsCommand: PendingUploadCommand {
    func addPendingUploads(_ pendingUploadsModel: PendingUploadsModel) async throws {
        try await pendingUploadsModel.addPendingUpload(forKey: mediaKey)
    }
}

/// Apply the update in Firestore.
extension UpdateUploadAnnotationsCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise abort (the command cannot be applied)
        guard try ctx.exists(.upload(uploadId)) else {
            throw FirestoreCommandError.obsolete("upload doesn't exist")
        }

        // ------------- WRITES ----------------
        ctx.updateData(
            [FirestoreUpload.CodingKeys.annotations.rawValue: annotations != nil
                ? annotations!.persistableValue
                : FieldValue.delete()],
            forDocument: .upload(uploadId)
        )
    }
}
