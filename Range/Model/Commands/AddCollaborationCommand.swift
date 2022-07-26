import Foundation
import RealmSwift

/// Add or update the `Collaboration`.
struct AddCollaborationCommand: Command, Equatable {
    let collaborationId: String
    var featureId: String
    var name: String
    var collaborationDescription: String
    var statusId: String?
    var tagIds: [String]

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
        let collaboration = Collaboration(id: collaborationId, name: name, description: collaborationDescription)
        if let statusId = statusId {
            collaboration.status = realm.objectOrPlaceholder(ofType: Status.self, forPrimaryKey: statusId)
        }
        collaboration.tags.removeAll()
        realm.add(collaboration, update: .modified)
        let tags = tagIds.compactMap { realm.objectOrPlaceholder(ofType: Tag.self, forPrimaryKey: $0) }
        collaboration.tags.append(objectsIn: tags)
        tags.forEach { $0.collaborations.insert(collaboration) }
        feature.collaborations.insert(collaboration)
    }
}
