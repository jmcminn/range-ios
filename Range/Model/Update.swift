import RealmSwift
import UIKit

/// Realm object for `project/updates/<id>`.
class Update: Object, WithPlaceholder {
    /// Supported updated fields
    enum Field: String, Codable, PersistableEnum {
        case name, description, statusName, assignee, dueDateTimestamp
    }

    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// Backlink to the Collaboration. This is automatically updated whenever this upload is added to or removed from the parent
    @Persisted(originProperty: "updates") var collaboration: LinkingObjects<Collaboration>
    // timestamp
    @Persisted var timestamp: Date
    // the user who created the update, needs to be optional because of how Realm
    // stores To-One relationships https://www.mongodb.com/docs/realm/sdk/swift/examples/define-a-realm-object-model/#define-a-to-one-relationship-property
    @Persisted var user: Participant?
    // field
    @Persisted var field: Field
    // old and new value type depends on the field, modelled as AnyRealmValue so it can contain any value
    // before change
    @Persisted var oldValue: AnyRealmValue // this can be null
    // after change
    @Persisted var newValue: AnyRealmValue // this can be null
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(
        id: String,
        timestamp: Date,
        field: Field,
        oldValue: AnyRealmValue,
        newValue: AnyRealmValue,
        placeholder: Bool = false
    ) {
        super.init()
        self.id = id
        self.timestamp = timestamp
        self.field = field
        self.oldValue = oldValue
        self.newValue = newValue
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(
            id: id,
            timestamp: Date(),
            field: .name,
            oldValue: AnyRealmValue.none,
            newValue: AnyRealmValue.none,
            placeholder: true
        )
    }
}
