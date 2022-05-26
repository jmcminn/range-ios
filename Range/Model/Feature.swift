import Foundation
import RealmSwift

/// Realm object for `project/details/feature/<id>`
class Feature: Object {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// Backlink to the Geometry. This is automatically updated whenever this feature is added to or removed from a geometry
    @Persisted(originProperty: "features") var geometry: LinkingObjects<Geometry>
    /// name
    @Persisted var name: String

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, name: String) {
        super.init()
        self.id = id
        self.name = name
    }
}
