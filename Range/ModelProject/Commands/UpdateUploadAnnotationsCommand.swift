import FirebaseFirestore
import Foundation
import RealmSwift

/// Update annotations for given Upload
struct UpdateUploadAnnotationsCommand: Command, Codable, Equatable {
    var operations: [CommandOperationType : [String]] {
        [.update: [uploadId]]
    }
    

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

/// Provide data for firebase function call
extension UpdateUploadAnnotationsCommand: FirebaseFunctionCommand {
    var functionName: String { "updateUpload" }

    var functionData: [String: Any?]? {
        [
            "uploadId": uploadId,
            "annotations": annotations?.persistableValue
        ]
    }
}
