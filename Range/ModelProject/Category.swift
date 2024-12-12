import RealmSwift
import SVGKit
import UIKit

/// Realm object for `project/<id>/categories/<id>`.
class Category: Object, WithPlaceholder, WithId {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// display name of the category
    @Persisted var name: String
    /// icon url
    @Persisted var iconUrl: URL?
    /// The default category for new Collaboration
    @Persisted var isDefault: Bool
    /// Defines the order of statuses. Status are sorted by this number ascending.
    @Persisted var order: Double
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    lazy var icon: UIImage? = iconUrl
        .flatMap { try? Data(contentsOf: $0) }
        .flatMap { SVGKImage(data: $0).uiImage.withRenderingMode(.alwaysTemplate) }

    // default first, then sorted by order
    static var uiSortingOrder: (Category, Category) -> Bool = { c1, c2 in
        if c1.isDefault { return true }
        if c2.isDefault { return false }
        return c1.order <= c2.order
    }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, name: String, iconUrl: URL?, isDefault: Bool, order: Double, placeholder: Bool = false) {
        super.init()
        self.id = id
        self.name = name
        self.iconUrl = iconUrl
        self.isDefault = isDefault
        self.order = order
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(id: id, name: "", iconUrl: nil, isDefault: false, order: 0)
    }
}
