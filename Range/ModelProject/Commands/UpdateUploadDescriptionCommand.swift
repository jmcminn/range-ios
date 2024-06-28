import FirebaseFirestore
import Foundation
import RealmSwift

/// Update description for given Upload
struct UpdateUploadDescriptionCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { .init([uploadId]) }

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

/// Provide data for firebase function call
extension UpdateUploadDescriptionCommand: FirebaseFunctionCommand {
    var functionName: String { "updateUpload" }

    func functionData(_ projectId: String) -> Any? {
        [
            "projectId": projectId,
            "uploadId": uploadId,
            "description": uploadDescription
        ]
    }
}
