
import CoreLocation
import Foundation
import RealmSwift

/// Represents the `Tag` (`projects/tagNames` path in Firebase)
///
/// Encoded as:
///
///     {
///         "name": "",
///     }
struct FirebaseTagName: Codable, FirestoreToRealmSyncable {
    typealias ModelType = Tag

    var name: String

    func upsertCommand(id: String) throws -> LocalCommand {
        UpsertTagCommand(tagId: id, name: name)
    }
}
