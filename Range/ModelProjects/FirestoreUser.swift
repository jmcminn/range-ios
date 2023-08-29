import Foundation
import OSLog
import RealmSwift

/// Represents the `User` (`users/{id}` path in Firestore)
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
struct FirestoreUser: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = User

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case firstName, lastName, avatarUrlString = "avatarUrl", email, permissions, fcmTokens
    }

    var firstName: String
    var lastName: String
    var avatarUrlString: String?
    var email: String
    var permissions: [String: [String]]?
    var fcmTokens: [String]?

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
        let organizationIds: [String] = (permissions?["organizations"] as? [String]) ?? []
        let projectIds: [String] = (permissions?["projects"] as? [String]) ?? []
        let user = User(
            id: id,
            firstName: firstName,
            lastName: lastName,
            avatarUrl: avatarUrl,
            email: email,
            organizationIds: organizationIds,
            projectIds: projectIds
        )
        realm.add(user, update: .modified)
    }
}
