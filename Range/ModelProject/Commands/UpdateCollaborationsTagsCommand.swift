import FirebaseFirestore
import Foundation
import RealmSwift

/// Update tags for given Collaboration(s)
struct UpdateCollaborationsTagsCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: Set<String> { .init(collaborationIds) }

    let collaborationIds: [String]
    var tags: [CommandTag]
    // should it add given tags to collaborations (true) or replace (false). Replace is the default behavior
    var add: Bool = false
}

extension UpdateCollaborationsTagsCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        let collaborationsToUpdate = try collaborationIds.map {
            // fail locally if any of the object doesn't exist, this shouldn't really happen
            try realm.object(ofType: Collaboration.self, forPrimaryKey: $0).or(error: ModelError.collaborationNotFound)
        }

        // add or update tags
        let tags = tags.map(\.asTag)
        tags.forEach { realm.add($0, update: .modified) }

        // update tags <-> collaboration
        let tagIds = tags.map(\.id)
        for collaboration in collaborationsToUpdate {
            if !add {
                // only remove previous tags if replacing (not adding)
                collaboration.cleanupOldTags(newTagIds: tagIds)
                collaboration.tags.removeAll()
            }
            collaboration.addNewTags(newTagIds: tagIds, realm: realm)
        }
    }
}

/// Apply the `Collaboration.tags` update in Firestore.
extension UpdateCollaborationsTagsCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise abort (the command cannot be applied)
        let collaborationsToUpdate = try collaborationIds.compactMap { id in
            if let collaboration = try ctx.getDocument(.collaboration(id), as: FirestoreCollaboration.self) {
                // return a pair of (id, collab) as FirestoreCollaboration doesn't contain the id
                return (id, collaboration)
            } else {
                return nil
            }
        }
        if !collaborationIds.isEmpty, collaborationsToUpdate.isEmpty {
            throw FirestoreCommandError.obsolete("collaboration doesn't exist")
        }

        // only add new tags... don't touch the existing ones
        let newTags = try tags.filter { try !ctx.exists(.tagName($0.id)) }

        // ------------- WRITES ----------------
        try newTags.forEach {
            try ctx.setData(from: $0.asFirestoreTagName, forDocument: .tagName($0.id))
        }
        let tagIds = tags.map(\.id)
        for (collaborationId, collaboration) in collaborationsToUpdate {
            let updatedTagIds: [String]
            if add {
                // keep the uploads tag ids and add *new tags only*
                var newTagIds = collaboration.tagIds
                for tagId in tagIds {
                    if !newTagIds.contains(tagId) {
                        newTagIds.append(tagId)
                    }
                }
                updatedTagIds = newTagIds
            } else {
                // just replace with given tag ids
                updatedTagIds = tagIds
            }
            ctx.updateData(
                [FirestoreCollaboration.CodingKeys.tagIds.rawValue: updatedTagIds],
                forDocument: .collaboration(collaborationId)
            )
        }
    }
}
