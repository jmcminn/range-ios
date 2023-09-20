import Foundation
import RealmSwift

/// Realm object for `users/invitations`.
class Invitation: Object, WithId {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// Inviter first name
    @Persisted var inviterFirstName: String
    /// Inviter last name
    @Persisted var inviterLastName: String
    /// Organization name
    @Persisted var organizationName: String
    // timestamp
    @Persisted var timestamp: Date

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, inviterFirstName: String, inviterLastName: String, organizationName: String, timestamp: Date) {
        super.init()
        self.id = id
        self.inviterFirstName = inviterFirstName
        self.inviterLastName = inviterLastName
        self.organizationName = organizationName
        self.timestamp = timestamp
    }
}

// MARK: - UI properties

extension Invitation {
    /// The value to display in the UI for inviter name
    var inviterDisplayName: String {
        var components: [String] = []
        if !inviterFirstName.isEmpty { components.append(inviterFirstName) }
        if !inviterLastName.isEmpty { components.append(inviterLastName) }
        return components.joined(separator: " ")
    }
}
