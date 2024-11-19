import RealmSwift
import UIKit

/// Realm object for `project/details/statusName/<id>`.
class Status: Object, WithPlaceholder, WithId {
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
    /// Defines the order of statuses. Status are sorted by this number ascending.
    @Persisted var order: Double?
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// Couldn't add CustomPersistable for UIColor, so we store the `hexColor` in db and add `color` variable to store UIColor.
    lazy var color = UIColor(hexString: hexColor) ?? .black

    /// Hardcoded order of statuses by name
    private static let hardcodedStatusOrder: [String] = ["In Progress", "Blocked", "Needs Review", "Complete"]

    // initial first, completed last, otherwise keep the ordering
    static var uiSortingOrder: (Status, Status) -> Bool = { s1, s2 in
        if s1.isInitial { return true }
        if s2.isInitial { return false }
        if s2.isCompleted { return true }
        if s1.isCompleted { return false }
        // if the statuses define order then sort by it
        if let order1 = s1.order, let order2 = s2.order {
            return order1 <= order2
        }
        if let index1 = hardcodedStatusOrder.firstIndex(of: s1.name),
           let index2 = hardcodedStatusOrder.firstIndex(of: s2.name)
        {
            return index1 < index2
        }
        return false
    }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, name: String, hexColor: String, isInitial: Bool, isCompleted: Bool, order: Double? = nil, placeholder: Bool = false) {
        super.init()
        self.id = id
        self.name = name
        self.hexColor = hexColor
        self.isInitial = isInitial
        self.isCompleted = isCompleted
        self.order = order
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(id: id, name: "", hexColor: "#000000", isInitial: false, isCompleted: false, order: nil, placeholder: true)
    }
}
