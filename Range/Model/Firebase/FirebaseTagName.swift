
import CoreLocation
import Foundation
import RealmSwift

/// Represents the `Tag` (`projects/details/tagNames` path in Firebase)
///
/// Encoded as:
///
///     {
///         "name": "",
///     }
struct FirebaseTagName: Codable, FirebaseToRealmSyncable {
    typealias ModelType = Tag

    var name: String

    /// Add or update the tag
    func upsert(_ realm: Realm, id: String) throws {
        let tag = Tag(id: id, name: name)

        // if the tag has local lastApplied keep it
        if let existingTag = realm.object(ofType: Tag.self, forPrimaryKey: id) {
            tag.lastApplied = existingTag.lastApplied
        }
        realm.add(tag, update: .modified)
    }
}
