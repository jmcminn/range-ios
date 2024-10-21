import Foundation
import RealmSwift

/// Realm object for `users/invitations` and `organizations/invitations`
class Invitation: Object, WithId {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// Invitee email
    @Persisted var inviteeEmail: String
    /// Inviter first name
    @Persisted var inviterFirstName: String
    /// Inviter last name
    @Persisted var inviterLastName: String
    /// Organization name
    @Persisted var organizationName: String
    /// Users role in the organization
    @Persisted var organizationRole: Participant.OrganizationRole = .Admin
    /// array of project ids the user is invited to
    @Persisted var projectIds: List<String>
    // timestamp
    @Persisted var timestamp: Date
    // last resentTimestamp, nil if only sent once
    @Persisted var resentTimestamp: Date?
    // if the invitation was accepted
    @Persisted var acceptedTimestamp: Date?

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(
        id: String,
        inviteeEmail: String,
        inviterFirstName: String,
        inviterLastName: String,
        organizationName: String,
        organizationRole: Participant.OrganizationRole,
        projectIds: [String],
        timestamp: Date,
        resentTimestamp: Date?,
        acceptedTimestamp: Date?
        
    ) {
        super.init()
        self.id = id
        self.inviteeEmail = inviteeEmail
        self.inviterFirstName = inviterFirstName
        self.inviterLastName = inviterLastName
        self.organizationName = organizationName
        self.organizationRole = organizationRole
        self.projectIds.append(objectsIn: projectIds)
        self.timestamp = timestamp
        self.resentTimestamp = resentTimestamp
        self.acceptedTimestamp = acceptedTimestamp
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
