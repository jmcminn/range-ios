import Foundation
import OSLog
import RealmSwift

/// Represents the `Participant` (`projects/details/participants` path in Firebase)
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
struct FirebaseParticipant: Decodable, FirebaseToRealmSyncable {
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
    func upsert(_ realm: Realm, id: String) throws {
        let avatarUrl: URL?
        if let avatarUrlString = avatarUrlString {
            avatarUrl = URL(string: avatarUrlString)
            if avatarUrl == nil {
                Logger.firebase.log("not well formed avatarUrl: \(avatarUrlString) for user: \(id)")
            }
        } else {
            avatarUrl = nil
        }
        realm.add(
            Participant(id: id, firstName: firstName, lastName: lastName, avatarUrl: avatarUrl, email: email),
            update: .modified
        )
    }
}
