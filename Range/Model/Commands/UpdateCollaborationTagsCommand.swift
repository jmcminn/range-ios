import FirebaseFirestore
import Foundation
import RealmSwift

/// Update tags for given Collaboration
struct UpdateCollaborationTagsCommand: Command, Codable, Equatable {
    let collaborationId: String
    var tags: [CommandTag]
}

extension UpdateCollaborationTagsCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) else {
            throw ModelError.collaborationNotFound
        }
        // add or update tags
        let tags = tags.map(\.asTag)
        tags.forEach { realm.add($0, update: .modified) }

        // update tags <-> collaboration
        let tagIds = tags.map(\.id)
        collaboration.cleanupOldTags(newTagIds: tagIds)
        collaboration.tags.removeAll()
        collaboration.addNewTags(newTagIds: tagIds, realm: realm)
    }
}

/// Apply the `Collaboration.tags` update in Firestore.
extension UpdateCollaborationTagsCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise abort (the command cannot be applied)
        guard try ctx.exists(.collaboration(collaborationId)) else {
            throw FirestoreCommandError.obsolete("collaboration doesn't exist")
        }
        // only add new tags... don't touch the existing ones
        let newTags = try tags.filter { try !ctx.exists(.tagName($0.id)) }

        // ------------- WRITES ----------------
        try newTags.forEach {
            try ctx.setData(from: $0.asFirestoreTagName, forDocument: .tagName($0.id))
        }
        let tagIds = tags.map(\.id)
        ctx.updateData(
            [FirebaseCollaboration.CodingKeys.tagIds.rawValue: tagIds],
            forDocument: .collaboration(collaborationId)
        )
    }
}
