import FirebaseFirestore
import Foundation
import RealmSwift

/// Delete the `Upload`s with given ids
struct DeleteUploadsCommand: Command, Codable, Equatable {
    var type: CommandType { .delete } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { .init(uploadIds) }

    let uploadIds: [String]
}

extension DeleteUploadsCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        var uploadsToRemove = [Upload]()
        for uploadId in uploadIds {
            // fail locally if any of the uploads doesn't exist, this shouldn't really happen
            guard let upload = realm.object(ofType: Upload.self, forPrimaryKey: uploadId) else {
                throw ModelError.uploadNotFound
            }
            uploadsToRemove.append(upload)
        }
        for upload in uploadsToRemove {
            realm.delete(upload)
        }
    }
}

extension DeleteUploadsCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise it's already removed
        let uploadIdsToRemove = try uploadIds.filter { try ctx.exists(.upload($0)) }

        // ------------- WRITES ----------------
        for uploadId in uploadIdsToRemove {
            ctx.deleteDocument(.upload(uploadId))
        }
    }
}
