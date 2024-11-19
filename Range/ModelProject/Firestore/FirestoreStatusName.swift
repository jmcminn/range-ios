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
struct FirestoreStatusName: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = Status

    var name: String
    var color: String
    var isInitial: Bool
    var isCompleted: Bool
    var order: Double?

    /// Convert FirestoreStatusName to Status with given id.
    /// TODO? this could be part of FirestoreToRealmSyncable if needed for other documents.
    func modelObject(withId id: String) -> ModelType {
        Status(id: id, name: name, hexColor: color, isInitial: isInitial, isCompleted: isCompleted, order: order)
    }

    func upsert(withId id: String, inRealm realm: Realm) throws {
        realm.add(modelObject(withId: id), update: .modified)
    }
}
