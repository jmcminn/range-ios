import RealmSwift
import UIKit

/// Realm object for `project/details/participants/<id>`.
class Participant: Object {
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

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, firstName: String, lastName: String, avatarUrl: URL?, email: String) {
        super.init()
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.avatarUrl = avatarUrl
        self.email = email
    }
}
