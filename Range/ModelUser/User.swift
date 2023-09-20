import RealmSwift
import UIKit

/// Realm object for `users/<id>`.
class User: Object, WithPlaceholder, WithId {
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
    /// array of organization ids this user has permission to access
    @Persisted var organizationIds: List<String>
    /// array of projects ids this user has permission to access
    @Persisted var projectIds: List<String>
    /// array of user fcmTokens (Firebase Cloud Messaging Tokens)
    @Persisted var fcmTokens: List<String>
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// Whether account is ready or this is a fresh user after a signup
    var accountReady: Bool { !firstName.isEmpty && firstName != email }

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
        organizationIds: [String] = [],
        projectIds: [String] = [],
        fcmTokens: [String] = [],
        placeholder: Bool = false
    ) {
        super.init()
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.avatarUrl = avatarUrl
        self.email = email
        self.organizationIds.append(objectsIn: organizationIds)
        self.projectIds.append(objectsIn: projectIds)
        self.fcmTokens.append(objectsIn: fcmTokens)
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
            organizationIds: [],
            projectIds: [],
            fcmTokens: [],
            placeholder: true
        )
    }
}
