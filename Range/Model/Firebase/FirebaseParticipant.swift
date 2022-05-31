import Foundation
import RealmSwift

import Foundation

/// Represents the `Participant` (`projects/details/participants` path in Firebase)
/// Decodable only - it's a readonly data
///
/// Encoded as:
/// {
///     "id": "23d84cf0-ee41-4dd5-8d91-940fd331a309",
///     "firebaseUid": "T8BAFTzwCVWtawq6yS9Ygax9Uxi1",
///     "projectRole": "admin",
///     "firstName": "Name",
///     "lastName": "Last name",
///     "timezone": "America/Los_Angeles",
///     "avatarUrl": "name.png",
///     "email": "email@domain.com"
/// }
struct FirebaseParticipant: Decodable, FirebaseToRealmSyncable {
    typealias ModelType = Participant

    var id: String
    var firstName: String
    var lastName: String
    var avatarUrl: String?
    var email: String

    /// Add or update the status
    func upsert(_ realm: Realm) throws {
        realm.add(
            Participant(id: id, firstName: firstName, lastName: lastName, avatarUrl: avatarUrl, email: email),
            update: .modified
        )
    }
}
