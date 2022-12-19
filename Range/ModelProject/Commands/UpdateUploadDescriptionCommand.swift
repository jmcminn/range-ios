import FirebaseFirestore
import Foundation
import RealmSwift

/// Update description for given Upload
struct UpdateUploadDescriptionCommand: Command, Codable, Equatable {
    var authorId: String
    let uploadId: String
    var uploadDescription: String?
}

extension UpdateUploadDescriptionCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let upload = realm.object(ofType: Upload.self, forPrimaryKey: uploadId) else {
            throw ModelError.uploadNotFound
        }
        upload.uploadDescription = uploadDescription
    }
}

/// Apply the update in Firestore.
extension UpdateUploadDescriptionCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise abort (the command cannot be applied)
        guard let upload = try ctx.getDocument(.upload(uploadId), as: FirestoreUpload.self)
        else {
            throw FirestoreCommandError.obsolete("upload doesn't exist")
        }
        guard upload.uploadDescription != uploadDescription else {
            // do nothing, the name is not really different...
            return
        }

        // ------------- WRITES ----------------
        ctx.updateData(
            [FirestoreUpload.CodingKeys.uploadDescription.rawValue: uploadDescription != nil
                ? uploadDescription!
                : FieldValue.delete()],
            forDocument: .upload(uploadId)
        )
    }
}
