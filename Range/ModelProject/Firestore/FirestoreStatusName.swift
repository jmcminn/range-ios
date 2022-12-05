import Foundation
import RealmSwift

/// Represents the `Status` (`projects/statusNames` path in Firestore)
///
/// Encoded as:
///
///     {
///         "name"       : "In Progress",
///         "color"      : "#5D81FF",
///         "isInitial"  : true,
///         "isCompleted": false,
///     }
struct FirestoreStatusName: Codable, FirestoreToRealmSyncable {
    typealias ModelType = Status

    var name: String
    var color: String
    var isInitial: Bool
    var isCompleted: Bool

    func upsert(withId id: String, inRealm realm: Realm) throws {
        let status = Status(id: id, name: name, hexColor: color, isInitial: isInitial, isCompleted: isCompleted)
        realm.add(status, update: .modified)
    }
}
