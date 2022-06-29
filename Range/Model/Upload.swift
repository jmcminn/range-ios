import RealmSwift
import UIKit

/// Realm object for `project/details/uploads/<id>`.
class Upload: Object {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    // the author, needs to be optional because of how Realm
    // stores To-One relationships https://www.mongodb.com/docs/realm/sdk/swift/examples/define-a-realm-object-model/#define-a-to-one-relationship-property
    @Persisted var author: Participant?
    // timestamp (since 1970)
    @Persisted var timestamp: TimeInterval
    // url
    @Persisted var url: URL
    // name
    @Persisted var name: String
    // description
    @Persisted var uploadDescription: String?
    /// tags attached to the upload, ordered
    @Persisted var tags: List<Tag>
    // TODO: 44 correlation

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, timestamp: TimeInterval, url: URL, name: String, description: String?) {
        super.init()
        self.id = id
        self.timestamp = timestamp
        self.url = url
        self.name = name
        uploadDescription = description
    }
}
