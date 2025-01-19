import FirebaseFirestore
import Foundation
import RealmSwift

/// Delete the `Upload` with given id
struct DeleteUploadCommand: Command, Codable, Equatable {
    var operations: [CommandOperationType: [String]] {
        [.delete: [uploadId]]
    }

    let uploadId: String
}

extension DeleteUploadCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        // fail locally if any of the uploads doesn't exist, this shouldn't really happen
        guard let upload = realm.object(ofType: Upload.self, forPrimaryKey: uploadId) else {
            throw ModelError.uploadNotFound
        }
        realm.delete(upload.comments)
        realm.delete(upload)
    }
}

/// Provide data for 'deleteUpload' firebase function call
extension DeleteUploadCommand: FirebaseFunctionCommand {
    var functionName: String { "deleteUpload" }

    var functionData: [String: Any?]? {
        ["uploadId": uploadId]
    }
}
