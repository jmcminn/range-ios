import Foundation
import RealmSwift

/// Realm object for `project/details/feature/<id>`
class Feature: Object {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// name
    @Persisted var name: String
    /// Backlink to the Geometry. This is automatically updated whenever this feature is added to or removed from a geometry
    @Persisted(originProperty: "features") var geometry: LinkingObjects<Geometry>
    /// collaborations for this feature, the order doesn't matter so it's a set
    @Persisted var collaborations: MutableSet<Collaboration>
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// Count all uploads from all collections
    var uploadsCount: Int {
        collaborations.reduce(0) { count, collaboration in
            count + collaboration.uploads.count
        }
    }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, name: String, placeholder: Bool = false) {
        super.init()
        self.id = id
        self.name = name
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder Feature
    convenience init(placeholder id: String) {
        self.init(
            id: id,
            name: "",
            placeholder: true
        )
    }
}
