import FirebaseFirestore
import Foundation
import RealmSwift

/// Update tags for given Collaboration
struct UpdateCollaborationTagsCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { [collaborationId] }

    let collaborationId: String
    var tags: [CommandTag]
    // should it add given tags to collaboration (true) or replace (false). Replace is the default behavior
    var add: Bool = false
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
        if !add {
            // only remove previous tags if replacing (not adding)
            collaboration.cleanupOldTags(newTagIds: tagIds)
            collaboration.tags.removeAll()
        }
        collaboration.addNewTags(newTagIds: tagIds, realm: realm)
    }
}

/// Provide data for firebase function call
extension UpdateCollaborationTagsCommand: FirebaseFunctionCommand {
    var functionName: String { "updateCollaboration" }

    func functionData(_ projectId: String) -> Any? {
        [
            "projectId": projectId,
            "collaborationId": collaborationId,
            "tags": tags.map { ["id": $0.id, "name": $0.name] },
            "addTags": add,
        ]
    }
}
