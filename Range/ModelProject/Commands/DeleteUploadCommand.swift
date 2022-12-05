import FirebaseFirestore
import Foundation
import RealmSwift

/// Delete the `Upload`
struct DeleteUploadCommand: Command, Codable, Equatable {
    let uploadId: String
}

extension DeleteUploadCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        // fail locally if the upload doesn't exist, this shouldn't really happen
        guard let upload = realm.object(ofType: Upload.self, forPrimaryKey: uploadId) else {
            throw ModelError.uploadNotFound
        }
        realm.delete(upload)
    }
}

extension DeleteUploadCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise it's already removed
        guard try ctx.exists(.upload(uploadId)) else { return }

        // ------------- WRITES ----------------
        ctx.deleteDocument(.upload(uploadId))
    }
}
