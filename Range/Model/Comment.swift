import RealmSwift
import UIKit

/// Realm object for `project/details/comments/<id>`.
class Comment: Object, WithPlaceholder {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    // comment authr, needs to be optional because of how Realm
    // stores To-One relationships https://www.mongodb.com/docs/realm/sdk/swift/examples/define-a-realm-object-model/#define-a-to-one-relationship-property
    @Persisted var author: Participant?
    // timestamp (since 1970)
    @Persisted var timestamp: TimeInterval
    // text
    @Persisted var text: String
    // whether the text was ever edited
    @Persisted var textIsEdited: Bool
    // whether it is a note (true) or a regular comment (false)
    @Persisted var isNote: Bool
    // who completed the note
    @Persisted var completedBy: Participant?
    // when it was completed (or uncompleted if nil)
    @Persisted var completedTimestamp: TimeInterval?
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// Derived property, whether the note is completed or not, based on the presence of completedTimestamp
    var completed: Bool {
        completedTimestamp != nil
    }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(
        id: String,
        timestamp: TimeInterval,
        text: String,
        textIsEdited: Bool,
        isNote: Bool,
        completedTimestamp: TimeInterval?,
        placeholder: Bool = false
    ) {
        super.init()
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.textIsEdited = textIsEdited
        self.isNote = isNote
        self.completedTimestamp = completedTimestamp
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(
            id: id,
            timestamp: 0,
            text: "",
            textIsEdited: false,
            isNote: false,
            completedTimestamp: nil,
            placeholder: true
        )
    }
}
