import Foundation
import RealmSwift

/// Realm object for `project/details/collaborations/<id>`
class Collaboration: Object {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// Backlink to the Feature. This is automatically updated whenever this coolaboration is added to or removed from the parent
    @Persisted(originProperty: "collaborations") var feature: LinkingObjects<Feature>
    /// Backlink to the Status. This is automatically updated whenever this coolaboration is added to or removed from the status
    /// Status is not really a parent of the collaboration, but to have this backling we need to model it on the Status level
    @Persisted(originProperty: "collaborations") var status: LinkingObjects<Status>
    /// name
    @Persisted var name: String
    /// description (can't really use the description name for it as it's already used)
    @Persisted var collaborationDescription: String

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, name: String, description: String) {
        super.init()
        self.id = id
        self.name = name
        collaborationDescription = description
    }
}
