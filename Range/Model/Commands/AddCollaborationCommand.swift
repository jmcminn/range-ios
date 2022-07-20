import Foundation
import RealmSwift

struct AddCollaborationCommand: Command {
    let collaborationId: String
    let featureId: String
    let name: String
    let collaborationDescription: String
    let statusId: String?
    var tagIds: [String]

    func applyLocally(inRealm realm: Realm) throws {
        let feature = realm.objectOrPlaceholder(ofType: Feature.self, forPrimaryKey: featureId)
        let collaboration = Collaboration(id: collaborationId, name: name, description: collaborationDescription)
        if let statusId = statusId {
            collaboration.status = realm.objectOrPlaceholder(ofType: Status.self, forPrimaryKey: statusId)
        }
        collaboration.tags.removeAll()
        realm.add(collaboration, update: .modified)
        let tags = tagIds.compactMap { realm.objectOrPlaceholder(ofType: Tag.self, forPrimaryKey: $0) }
        collaboration.tags.append(objectsIn: tags)
        // TODO: 44 remove the collaboration from the tags it was attached to and is not anymore
        tags.forEach { $0.collaborations.insert(collaboration) }
        feature.collaborations.insert(collaboration)
    }
}
