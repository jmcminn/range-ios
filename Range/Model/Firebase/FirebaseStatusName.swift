import Foundation
import RealmSwift

/// Represents the `Status` (`projects/details/statusNames` path in Firebase)
///
/// Encoded as:
///
///     {
///         "id"         : "0521fccf-3799-4786-aab1-e5e5108c0807",
///         "name"       : "In Progress",
///         "color"      : "#5D81FF",
///         "isInitial"  : true,
///         "isCompleted": false,
///     }
struct FirebaseStatusName: Codable, FirebaseToRealmSyncable {
    typealias ModelType = Status

    var id: String
    var name: String
    var color: String
    var isInitial: Bool
    var isCompleted: Bool

    /// Add or update the status
    func upsert(_ realm: Realm) throws {
        realm.add(
            Status(id: id, name: name, hexColor: color, isInitial: isInitial, isCompleted: isCompleted),
            update: .modified
        )
    }
}
