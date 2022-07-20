import Foundation
import RealmSwift

/// Realm object for `project/details/collaborations/<id>`
class Collaboration: Object, WithPlaceholder {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// Backlink to the Feature. This is automatically updated whenever this coolaboration is added to or removed from the parent
    @Persisted(originProperty: "collaborations") var feature: LinkingObjects<Feature>
    // collaboration status, needs to be optional because of how Realm
    // stores To-One relationships https://www.mongodb.com/docs/realm/sdk/swift/examples/define-a-realm-object-model/#define-a-to-one-relationship-property
    @Persisted var status: Status?
    /// name
    @Persisted var name: String
    /// description (can't really use the description name for it as it's already used)
    @Persisted var collaborationDescription: String
    /// comments, the order doesn't matter so it's a set (the order is controlled by the comment timestamp when displaying in the UI)
    @Persisted var comments: MutableSet<Comment>
    /// uploads, the order doesn't matter so it's a set (the order is controlled by the upload timestamp when displaying in the UI)
    @Persisted var uploads: MutableSet<Upload>
    /// tags attached to the upload, ordered
    @Persisted var tags: List<Tag>
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, name: String, description: String, placeholder: Bool = false) {
        super.init()
        self.id = id
        self.name = name
        collaborationDescription = description
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(
            id: id,
            name: "",
            description: "",
            placeholder: true
        )
    }
}
