import RealmSwift
import UIKit

/// Realm object for `project/details/participants/<id>`.
class Participant: Object, WithPlaceholder {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// user first name (@objc added so it can be used in SortDescriptor)
    @objc @Persisted var firstName: String
    /// user last name
    @objc @Persisted var lastName: String
    /// avatar url
    @Persisted var avatarUrl: URL?
    /// email
    @Persisted var email: String
    /// array of projects ids this user has permission to access
    @Persisted var projectIds: List<String>
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// The value to display in the UI
    var displayName: String {
        var components: [String] = []
        if !firstName.isEmpty { components.append(firstName) }
        if !lastName.isEmpty { components.append(lastName) }
        return components.joined(separator: " ")
    }

    var initials: String {
        if let firstNameLetter = firstName.first { return String(firstNameLetter) }
        if let lastNameLetter = lastName.first { return String(lastNameLetter) }
        return ""
    }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(
        id: String,
        firstName: String,
        lastName: String,
        avatarUrl: URL?,
        email: String,
        projectIds: [String] = [],
        placeholder: Bool = false
    ) {
        super.init()
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.avatarUrl = avatarUrl
        self.email = email
        self.projectIds.append(objectsIn: projectIds)
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
            projectIds: [],
            placeholder: true
        )
    }
}
