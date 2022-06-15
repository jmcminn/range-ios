import RealmSwift
import UIKit

/// Realm object for `project/details/tagNames/<id>`.
class Tag: Object {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    // name
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
