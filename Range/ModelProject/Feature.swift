import Foundation
import RealmSwift

/// Realm object for `project/details/feature/<id>`
class Feature: Object, WithPlaceholder, WithId {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// name
    @Persisted var name: String
    /// description (can't really use the description name for it as it's already used)
    @Persisted var featureDescription: String?
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

    /// If any collaboration has uncompleted notes
    var hasUncompletedNotes: Bool {
        collaborations.contains { $0.hasUncompletedNotes }
    }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, name: String, description: String?, placeholder: Bool = false) {
        super.init()
        self.id = id
        self.name = name
        featureDescription = description
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(
            id: id,
            name: "",
            description: nil,
            placeholder: true
        )
    }
}
