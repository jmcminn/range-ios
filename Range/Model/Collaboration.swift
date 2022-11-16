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
    // the author, needs to be optional because of how Realm
    // stores To-One relationships https://www.mongodb.com/docs/realm/sdk/swift/examples/define-a-realm-object-model/#define-a-to-one-relationship-property
    @Persisted var author: Participant?
    // timestamp
    @Persisted var timestamp: Date
    /// name
    @Persisted var name: String
    /// description (can't really use the description name for it as it's already used)
    @Persisted var collaborationDescription: String?
    /// comments, the order doesn't matter so it's a set (the order is controlled by the comment timestamp when displaying in the UI)
    @Persisted var comments: MutableSet<Comment>
    /// uploads, the order doesn't matter so it's a set (the order is controlled by the upload timestamp when displaying in the UI)
    @Persisted var uploads: MutableSet<Upload>
    /// updates, the order doesn't matter so it's a set (the order is controlled by the upload timestamp when displaying in the UI)
    @Persisted var updates: MutableSet<Update>
    /// tags attached to the upload, ordered
    @Persisted var tags: List<Tag>
    /// optional assignee
    @Persisted var assignee: Participant?
    /// due date timestamp
    @Persisted var dueDateTimestamp: Date?
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// If it has uncompleted notes
    var hasUncompletedNotes: Bool {
        comments.contains { $0.isNote == true && $0.completedBy == nil }
    }

    /// Whether the due date passed already
    var isOverdue: Bool {
        dueDateTimestamp != nil && dueDateTimestamp! < Date.now
    }

    /// Whether the collaboration is archived, based on the geometry.archivedTimestamp existence
    var isArchived: Bool {
        feature.first?.geometry.first?.archivedTimestamp != nil
    }

    /// it's completed if it has a status with isCompleted = true
    var isCompleted: Bool {
        status != nil && status!.isCompleted
    }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(
        id: String,
        timestamp: Date,
        name: String,
        description: String?,
        placeholder: Bool = false,
        dueDateTimestamp: Date? = nil
    ) {
        super.init()
        self.id = id
        self.timestamp = timestamp
        self.name = name
        collaborationDescription = description
        self.dueDateTimestamp = dueDateTimestamp
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(
            id: id,
            timestamp: Date(),
            name: "",
            description: nil,
            placeholder: true
        )
    }
}
