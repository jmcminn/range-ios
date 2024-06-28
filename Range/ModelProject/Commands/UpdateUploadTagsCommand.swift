import FirebaseFirestore
import Foundation
import RealmSwift

/// Update tags for given Upload
struct UpdateUploadTagsCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { .init([uploadId]) }

    let uploadId: String
    var tags: [CommandTag]
}

extension UpdateUploadTagsCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let upload = realm.object(ofType: Upload.self, forPrimaryKey: uploadId) else {
            throw ModelError.uploadNotFound
        }

        // add or update tags
        let tags = tags.map(\.asTag)
        tags.forEach { realm.add($0, update: .modified) }

        // update tags <-> upload
        let tagIds = tags.map(\.id)
        upload.cleanupOldTags(newTagIds: tagIds)
        upload.tags.removeAll()
        upload.addNewTags(newTagIds: tagIds, realm: realm)
    }
}

/// Provide data for firebase function call
extension UpdateUploadTagsCommand: FirebaseFunctionCommand {
    var functionName: String { "updateUpload" }

    func functionData(_ projectId: String) -> Any? {
        [
            "projectId": projectId,
            "uploadId": uploadId,
            "tags": tags.map { ["id": $0.id, "name": $0.name] },
        ]
    }
}
