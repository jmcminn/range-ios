import RealmSwift
import UIKit

/// Realm object for `project/details/comments/<id>`.
class Comment: Object {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    // comment authr, needs to be optional because of how Realm
    // stores To-One relationships https://www.mongodb.com/docs/realm/sdk/swift/examples/define-a-realm-object-model/#define-a-to-one-relationship-property
    @Persisted var author: Participant?
    // timestamp (since 1970)
    @Persisted var timestamp: TimeInterval
    // text
    @Persisted var text: String
    // optional because it might be not marked as "to complete"
    @Persisted var isCompleted: Bool?

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, timestamp: TimeInterval, text: String, isCompleted: Bool?) {
        super.init()
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.isCompleted = isCompleted
    }
}
