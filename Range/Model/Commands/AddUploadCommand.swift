import Foundation
import RealmSwift

class AddUploadCommand: Command, Equatable, Codable {
    let uploadId: String
    let collaborationId: String
    let userId: String
    let localUploadURL: URL
    let tagViewModels: [TagViewModel]
    let uploadDescription: String

    init(
        uploadId: String,
        collaborationId: String,
        userId: String,
        localUploadURL: URL,
        tags tagViewModels: [TagViewModel],
        description: String
    ) {
        self.uploadId = uploadId
        self.collaborationId = collaborationId
        self.userId = userId
        self.localUploadURL = localUploadURL
        self.tagViewModels = tagViewModels
        uploadDescription = description
    }

    static func == (lhs: AddUploadCommand, rhs: AddUploadCommand) -> Bool {
        lhs.uploadId == rhs.uploadId
    }
}

extension AddUploadCommand: LocalCommand {
    func applyLocally(writer: ProjectModelWriter) async throws {
        let upload = Upload(
            id: uploadId,
            timestamp: Date.now.timeIntervalSince1970,
            url: localUploadURL,
            name: "",
            description: uploadDescription
        )
        let tags = tagViewModels.map {
            Tag(id: $0.id, name: $0.name, lastApplied: Date.now.timeIntervalSince1970)
        }

        try await writer.write { realm in
            guard let user = realm.object(ofType: Participant.self, forPrimaryKey: self.userId) else {
                throw ModelError.currentUserNotFound
            }
            guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: self.collaborationId)
            else {
                throw ModelError.collaborationNotFound
            }
            realm.add(upload)
            realm.add(tags, update: .modified)
            upload.tags.append(objectsIn: tags)
            tags.forEach { $0.uploads.insert(upload) }
            upload.author = user
            collaboration.uploads.insert(upload)
        }
    }
}
