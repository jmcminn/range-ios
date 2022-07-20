import RealmSwift
import UIKit

/// Realm object for `project/details/statusName/<id>`.
class Status: Object, WithPlaceholder {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// display name of the status
    @Persisted var name: String
    /// color of the status pill
    @Persisted var hexColor: String
    /// The default status for new Collaboration
    @Persisted var isInitial: Bool
    /// The status denoting that the collaboration is complete
    @Persisted var isCompleted: Bool
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// Couldn't add CustomPersistable for UIColor, so we store the `hexColor` in db and add `color` variable to store UIColor.
    lazy var color = UIColor(hexString: hexColor)

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, name: String, hexColor: String, isInitial: Bool, isCompleted: Bool, placeholder: Bool = false) {
        super.init()
        self.id = id
        self.name = name
        self.hexColor = hexColor
        self.isInitial = isInitial
        self.isCompleted = isCompleted
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(id: id, name: "", hexColor: "#000000", isInitial: false, isCompleted: false, placeholder: true)
    }
}
