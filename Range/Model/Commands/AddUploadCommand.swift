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
    var tagIds: [String]

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
        upload.author = author
        realm.add(upload, update: .modified)

        let tags = tagIds.compactMap { realm.objectOrPlaceholder(ofType: Tag.self, forPrimaryKey: $0) }
        upload.tags.append(objectsIn: tags)
        // TODO: 44 remove the object from the tags it was attached to and is not anymore
        // unit test first...
        tags.forEach { $0.uploads.insert(upload) }

        collaboration.uploads.insert(upload)
    }
}
