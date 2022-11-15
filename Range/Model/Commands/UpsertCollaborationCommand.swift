import Foundation
import RealmSwift

/// Add or update the `Collaboration` in local Realm db.
struct UpsertCollaborationCommand: LocalCommand, Equatable {
    let collaborationId: String
    var featureId: String
    var authorId: String?
    var timestamp: Date
    var name: String
    var collaborationDescription: String?
    var statusId: String?
    var tagIds: [String]
    var assigneeId: String?
    var dueDateTimestamp: Date?

    /// remove the collaboration from the tags it was attached to and is not anymore
    static func cleanupOldTags(collaboration: Collaboration, newTagIds: [String]) {
        // for fast lookup
        let tagIdsSet = Set(newTagIds)
        for tag in collaboration.tags {
            if !tagIdsSet.contains(tag.id) {
                // updated tags don't contain this tag, remove the collaboration from it
                tag.collaborations.remove(collaboration)
            }
        }
    }

    /// Add given tags do collaboration and also link the Collaboration in Tags
    static func addNewTags(collaboration: Collaboration, newTagIds: [String], realm: Realm) {
        let tags = newTagIds.uniqued().compactMap { realm.objectOrPlaceholder(ofType: Tag.self, forPrimaryKey: $0) }
        collaboration.tags.append(objectsIn: tags)
        tags.forEach { $0.collaborations.insert(collaboration) }
    }

    func apply(inRealm realm: Realm) throws {
        if let existingCollaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) {
            UpsertCollaborationCommand.cleanupOldTags(collaboration: existingCollaboration, newTagIds: tagIds)
        }

        let feature = realm.objectOrPlaceholder(ofType: Feature.self, forPrimaryKey: featureId)
        let collaboration = Collaboration(
            id: collaborationId,
            timestamp: timestamp,
            name: name,
            description: collaborationDescription,
            dueDateTimestamp: dueDateTimestamp
        )
        if let authorId = authorId {
            collaboration.author = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: authorId)
        }
        if let statusId = statusId {
            collaboration.status = realm.objectOrPlaceholder(ofType: Status.self, forPrimaryKey: statusId)
        }
        if let assigneeId = assigneeId {
            collaboration.assignee = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: assigneeId)
        }
        realm.add(collaboration, update: .modified)
        collaboration.tags.removeAll()
        feature.collaborations.insert(collaboration)
        UpsertCollaborationCommand.addNewTags(collaboration: collaboration, newTagIds: tagIds, realm: realm)
    }
}
