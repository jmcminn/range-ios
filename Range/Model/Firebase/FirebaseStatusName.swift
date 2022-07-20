import Foundation
import RealmSwift

/// Represents the `Status` (`projects/statusNames` path in Firebase)
///
/// Encoded as:
///
///     {
///         "name"       : "In Progress",
///         "color"      : "#5D81FF",
///         "isInitial"  : true,
///         "isCompleted": false,
///     }
struct FirebaseStatusName: Codable, FirestoreToRealmSyncable {
    typealias ModelType = Status

    var name: String
    var color: String
    var isInitial: Bool
    var isCompleted: Bool

    func upsertCommand(id: String) throws -> Command {
        AddStatusCommand(statusId: id, name: name, color: color, isInitial: isInitial, isCompleted: isCompleted)
    }
}
