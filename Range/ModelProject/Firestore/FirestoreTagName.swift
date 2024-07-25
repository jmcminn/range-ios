
import CoreLocation
import Foundation
import RealmSwift

/// Represents the `Tag` (`projects/tagNames` path in Firestore)
///
/// Encoded as:
///
///     {
///         "name": "",
///     }
struct FirestoreTagName: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = Tag

    var name: String

    func upsert(withId id: String, inRealm realm: Realm) throws {
        let tag = Tag(id: id, name: name)
        realm.add(tag, update: .modified)
    }
}
