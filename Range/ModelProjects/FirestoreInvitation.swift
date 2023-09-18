import FirebaseFirestore
import Foundation
import RealmSwift

/// Represents the `Invitation` (`users/invitations/` path in Firestore)
struct FirestoreInvitation: Codable, FirestoreToRealmSyncable {
    typealias ModelType = Invitation

    /// Inviter first name
    var inviterFirstName: String
    /// Inviter last name
    var inviterLastName: String
    /// Organization name
    var organizationName: String
    // timestamp
    var timestamp: Timestamp

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case inviterFirstName, inviterLastName, organizationName, timestamp
    }

    func upsert(withId id: String, inRealm realm: Realm) throws {
        let invitation = Invitation(
            id: id,
            inviterFirstName: inviterFirstName,
            inviterLastName: inviterLastName,
            organizationName: organizationName,
            timestamp: timestamp.dateValue()
        )
        realm.add(invitation, update: .modified)
    }
}
