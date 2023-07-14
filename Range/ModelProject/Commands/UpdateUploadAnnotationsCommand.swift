import FirebaseFirestore
import Foundation
import RealmSwift

/// Update annotations for given Upload
struct UpdateUploadAnnotationsCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: Set<String> { .init([uploadId]) }

    let uploadId: String
    var annotations: Annotations?
}

extension UpdateUploadAnnotationsCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let upload = realm.object(ofType: Upload.self, forPrimaryKey: uploadId) else {
            throw ModelError.uploadNotFound
        }
        upload.annotations = annotations
    }
}

/// Apply the update in Firestore.
extension UpdateUploadAnnotationsCommand: FirestoreCommand {
    func apply(inFirestore _: FirestoreCommandContext) throws {
        // TODO: 1271 store in firestore
    }
}
