import Foundation
import OSLog
import RealmSwift

/// Represents the `Participant` (`projects/participants` path in Firestore)
/// Decodable only - it's a readonly data
///
/// Encoded as:
/// {
///     "projectRole": "admin",
///     "firstName": "Name",
///     "lastName": "Last name",
///     "timezone": "America/Los_Angeles",
///     "avatarUrl": "name.png",
///     "email": "email@domain.com"
/// }
struct FirestoreParticipant: Decodable, FirestoreToRealmSyncable, FirestoreToRealmSyncableWithCustomDelete {
    typealias ModelType = Participant

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case firstName, lastName, avatarUrlString = "avatarUrl", email
    }

    var firstName: String
    var lastName: String
    var avatarUrlString: String?
    var email: String

    /// Add or update the status.
    /// Ignores not well formed avatarUrl
    func upsert(withId id: String, inRealm realm: Realm) throws {
        let avatarUrl: URL?
        if let avatarUrlString = avatarUrlString {
            avatarUrl = URL(string: avatarUrlString)
            if avatarUrl == nil {
                Logger.firestore.log("not well formed avatarUrl: \(avatarUrlString) for user: \(id)")
            }
        } else {
            avatarUrl = nil
        }
        let participant = Participant(
            id: id,
            firstName: firstName,
            lastName: lastName,
            avatarUrl: avatarUrl,
            email: email,
            participation: .active
        )
        realm.add(participant, update: .modified)
    }

    func customDelete(object: RealmSwift.Object, inRealm _: RealmSwift.Realm) {
        guard let participant = object as? Participant else { return }
        // mark as removed but only if it's active, if it's suspended then it's covered by FirestoreSuspendedParticipant
        if participant.participation == .active {
            participant.participation = .removed
        }
    }
}
