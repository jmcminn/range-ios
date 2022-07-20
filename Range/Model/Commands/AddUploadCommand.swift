import Foundation
import RealmSwift

struct AddUploadCommand: Command {
    let uploadId: String
    let correlationId: String
    let parentType: String
    let parentId: String
    let authorId: String
    let timestamp: TimeInterval
    let name: String?
    let uploadDescription: String?
    let url: URL?

    func applyLocally(inRealm realm: Realm) throws {
        let collaboration = realm.objectOrPlaceholder(ofType: Collaboration.self, forPrimaryKey: parentId)
        let author = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: authorId)
        let upload = Upload(
            id: uploadId,
            timestamp: timestamp,
            url: url,
            name: name,
            description: uploadDescription,
            correlationId: correlationId
        )
        // TODO: 44 add tags for upload, and update tag.uploads when upserting
        upload.author = author
        realm.add(upload, update: .modified)
        collaboration.uploads.insert(upload)
    }
}
