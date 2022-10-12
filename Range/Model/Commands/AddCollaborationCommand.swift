import Foundation
import RealmSwift

/// Add or update the `Collaboration`.
struct AddCollaborationCommand: Command, Equatable {
    let collaborationId: String
    var featureId: String
    var authorId: String?
    var timestamp: TimeInterval?
    var name: String
    var collaborationDescription: String?
    var statusId: String?
    var tagIds: [String]
    var assigneeId: String?
    var dueDateTimestamp: TimeInterval?

    func apply(inRealm realm: Realm) throws {
        // remove the collaboration from the tags it was attached to and is not anymore
        if let existingCollaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) {
            // for fast lookup
            let tagIdsSet = Set(tagIds)
            for tag in existingCollaboration.tags {
                if !tagIdsSet.contains(tag.id) {
                    // updated tags don't contain this tag, remove the collaboration from it
                    tag.collaborations.remove(existingCollaboration)
                }
            }
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
        collaboration.tags.removeAll()
        realm.add(collaboration, update: .modified)
        let tags = tagIds.compactMap { realm.objectOrPlaceholder(ofType: Tag.self, forPrimaryKey: $0) }
        collaboration.tags.append(objectsIn: tags)
        tags.forEach { $0.collaborations.insert(collaboration) }
        feature.collaborations.insert(collaboration)
    }
}
