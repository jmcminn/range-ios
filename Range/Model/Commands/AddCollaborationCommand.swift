import Foundation
import RealmSwift

struct AddCollaborationCommand: Command, Equatable {
    let collaborationId: String
    var featureId: String
    var name: String
    var collaborationDescription: String
    var statusId: String?
    var tagIds: [String]

    func apply(inRealm realm: Realm) throws {
        let feature = realm.objectOrPlaceholder(ofType: Feature.self, forPrimaryKey: featureId)
        let collaboration = Collaboration(id: collaborationId, name: name, description: collaborationDescription)
        if let statusId = statusId {
            collaboration.status = realm.objectOrPlaceholder(ofType: Status.self, forPrimaryKey: statusId)
        }
        collaboration.tags.removeAll()
        realm.add(collaboration, update: .modified)
        let tags = tagIds.compactMap { realm.objectOrPlaceholder(ofType: Tag.self, forPrimaryKey: $0) }
        collaboration.tags.append(objectsIn: tags)
        // TODO: 44 remove the collaboration from the tags it was attached to and is not anymore + unit test
        tags.forEach { $0.collaborations.insert(collaboration) }
        feature.collaborations.insert(collaboration)
    }
}
