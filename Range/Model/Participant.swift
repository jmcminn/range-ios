import RealmSwift
import UIKit

/// Realm object for `project/details/participants/<id>`.
class Participant: Object, WithPlaceholder {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// user first name
    @Persisted var firstName: String
    /// user last name
    @Persisted var lastName: String
    /// avatar url
    @Persisted var avatarUrl: URL?
    /// email
    @Persisted var email: String
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// The value to display in the UI
    var displayName: String {
        var components: [String] = []
        if !firstName.isEmpty { components.append(firstName) }
        if !lastName.isEmpty { components.append(lastName) }
        return components.joined(separator: " ")
    }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, firstName: String, lastName: String, avatarUrl: URL?, email: String, placeholder: Bool = false) {
        super.init()
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.avatarUrl = avatarUrl
        self.email = email
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(
            id: id,
            firstName: "",
            lastName: "",
            avatarUrl: nil,
            email: "",
            placeholder: true
        )
    }
}
