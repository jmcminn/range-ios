import Foundation
import RealmSwift

/// Realm object for `project/<projectId>/collaborations/<id>`
class Collaboration: Object, WithPlaceholder, WithId {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    // collaboration category, needs to be optional because of how Realm
    // stores To-One relationships https://www.mongodb.com/docs/realm/sdk/swift/examples/define-a-realm-object-model/#define-a-to-one-relationship-property
    @Persisted var category: Category?
    /// Backlink to the Geometry. This is automatically updated whenever this coolaboration is added to or removed from the parent
    @Persisted(originProperty: "collaborations") var geometry: LinkingObjects<Geometry>
    // collaboration status, needs to be optional because of how Realm
    // stores To-One relationships https://www.mongodb.com/docs/realm/sdk/swift/examples/define-a-realm-object-model/#define-a-to-one-relationship-property
    @Persisted var status: Status?
    // the author, needs to be optional because of how Realm
    // stores To-One relationships https://www.mongodb.com/docs/realm/sdk/swift/examples/define-a-realm-object-model/#define-a-to-one-relationship-property
    @Persisted var author: Participant?
    // createdAt
    @Persisted var createdAt: Date
    // lastUpdatedAt
    @Persisted var lastUpdatedAt: Date
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
    /// identifier for the UI
    @Persisted var identifier: String?
    /// project participants following this collaboration
    @Persisted var followers: List<Participant>
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
        geometry.first?.archivedTimestamp != nil
    }

    /// it's completed if it has a status with isCompleted = true
    var isCompleted: Bool {
        status != nil && status!.isCompleted
    }

    /// The timestamp of the most recent Update or Comment or Upload or `timestamp` if no updates
    var lastUpdatedTimestamp: Date {
        ([lastUpdatedAt] + Array(uploads.map(\.lastUpdatedAt)) + Array(comments.map(\.lastUpdatedAt)))
            .max() ?? lastUpdatedAt
    }

    var isGeolocated: Bool {
        guard let canvasSource = geometry.first?.canvas.first?.canvasSources.first else { return false }
        return canvasSource.isGeolocated
    }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(
        id: String,
        createdAt: Date,
        lastUpdatedAt: Date,
        name: String,
        description: String?,
        dueDateTimestamp: Date? = nil,
        identifier: String? = nil,
        placeholder: Bool = false
    ) {
        super.init()
        self.id = id
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.name = name
        collaborationDescription = description
        self.dueDateTimestamp = dueDateTimestamp
        self.identifier = identifier
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(
            id: id,
            createdAt: Date(),
            lastUpdatedAt: Date(),
            name: "",
            description: nil,
            placeholder: true
        )
    }

    // MARK: - upsert/command helper functions

    /// remove the collaboration from the tags it was attached to and is not anymore
    func cleanupOldTags(newTagIds: [String]) {
        // for fast lookup
        let tagIdsSet = Set(newTagIds)
        for tag in tags {
            if !tagIdsSet.contains(tag.id) {
                // updated tags don't contain this tag, remove the collaboration from it
                tag.collaborations.remove(self)
            }
        }
    }

    /// Add given tags to collaboration and also link the Collaboration in Tags
    func addNewTags(newTagIds: [String], realm: Realm) {
        // for fast lookup
        let currentTagIdsSet = Set(tags.map(\.id))

        let newTags = newTagIds.uniqued()
            .filter { !currentTagIdsSet.contains($0) }
            .compactMap { realm.objectOrPlaceholder(ofType: Tag.self, forPrimaryKey: $0) }
        tags.append(objectsIn: newTags)
        newTags.forEach { $0.collaborations.insert(self) }
    }

    func addNewFollowers(newFollowerIds: [String], realm: Realm) {
        // for fast lookup
        let currentIdsSet = Set(followers.map(\.id))

        let newFollowers = newFollowerIds.uniqued()
            .filter { !currentIdsSet.contains($0) }
            .compactMap { realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: $0) }
        followers.append(objectsIn: newFollowers)
    }
}
