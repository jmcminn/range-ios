
import CoreLocation
import Foundation
import RealmSwift

/// Represents the `Tag` (`projects/details/tagNames` path in Firebase)
///
/// Encoded as:
///
///     {
///         "id":  "6ebe0ded-414b-4a5e-be09-5d079d5dd7dc",
///         "name": "",
///     }
struct FirebaseTagName: Codable, FirebaseToRealmSyncable {
    typealias ModelType = Tag

    var id: String
    var name: String

    /// Add or update the tag
    func upsert(_ realm: Realm) throws {
        let tag = Tag(id: id, name: name)

        // if the tag has local lastApplied keep it
        if let existingTag = realm.object(ofType: Tag.self, forPrimaryKey: id) {
            tag.lastApplied = existingTag.lastApplied
        }
        realm.add(tag, update: .modified)
    }
}
