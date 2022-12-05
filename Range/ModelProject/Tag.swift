import RealmSwift
import UIKit

/// Realm object for `project/details/tagNames/<id>`.
class Tag: Object, WithPlaceholder {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    // name
    @Persisted var name: String
    /// all the collaborations the tag is attached to
    @Persisted var collaborations: MutableSet<Collaboration>
    /// all the uploads the tag is attached to
    @Persisted var uploads: MutableSet<Upload>
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// Count how many times the tag was applied. Sum uploads, collaborations, etc.
    /// For now only uploads...
    var usageCount: Int {
        collaborations.count + uploads.count
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

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(id: id, name: "", placeholder: true)
    }
}
