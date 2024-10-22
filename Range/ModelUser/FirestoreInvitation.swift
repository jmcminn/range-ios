import FirebaseFirestore
import Foundation
import RealmSwift

/// Represents the `Invitation` (`users/invitations/` path in Firestore)
struct FirestoreInvitation: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = Invitation

    // accepted timestamp
    var acceptedTimestamp: Date?
    /// Invitee email
    var inviteeEmail: String
    /// Inviter first name
    var inviterFirstName: String
    /// Inviter last name
    var inviterLastName: String
    /// Organization name
    var organizationName: String
    /// Organization role
    var organizationRole: String
    /// project ids
    var projectIds: [String]?
    // timestamp
    var resentTimestamp: Date?
    // timestamp
    var timestamp: Date

    /// CodingKeys used by Codable as a keys in the encoded form
    enum CodingKeys: String, CodingKey {
        case acceptedTimestamp, inviteeEmail, inviterFirstName, inviterLastName, organizationName, organizationRole, projectIds, resentTimestamp, timestamp
    }

    func upsert(withId id: String, inRealm realm: Realm) throws {
        let role = try Participant.OrganizationRole.allCases.first { $0.rawValue == organizationRole }
            .or(error: ModelError.organizationRoleNotSupported(organizationRole))
        let invitation = Invitation(
            id: id,
            inviteeEmail: inviteeEmail,
            inviterFirstName: inviterFirstName,
            inviterLastName: inviterLastName,
            organizationName: organizationName,
            organizationRole: role,
            projectIds: projectIds ?? [],
            timestamp: timestamp,
            resentTimestamp: resentTimestamp,
            acceptedTimestamp: acceptedTimestamp
        )
        realm.add(invitation, update: .modified)
    }
}
