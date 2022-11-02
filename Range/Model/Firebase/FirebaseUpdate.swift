import CoreLocation
import FirebaseFirestore
import Foundation
import RealmSwift

/// Represents the `Update` (`projects/updates` path in Firebase)
///
/// Encoded as:
///
///     {
///         "parent": "13083d62-03a1-43d7-8eb0-ca5bb8b357f3",
///         "parentType": "Collaboration",
///         "timestamp": 1649228400000,
///         "user": "9e06df97-aa0f-4e0f-8c78-8892bfb126ec",
///         "field": "name",
///         "oldValue": "name", // optional, type depends on the field
///         "newValue": null // optional, type depends on the field
///     }
struct FirebaseUpdate: Codable, FirestoreToRealmSyncable {
    typealias ModelType = Update

    /// CodingKeys used by Codable as a keys in the encoded form
    enum CodingKeys: String, CodingKey {
        case parentId = "parent", parentType, timestamp, userId = "user", field, oldValue, newValue
    }

    var parentId: String
    var parentType: String
    var timestamp: Timestamp
    var userId: String
    var field: String // allow anything but constrain to supported Update.Field when upserting
    // old and new value can have different types depending on the field. For now Int, String or
    // Date is supported. The support needs to be made on the firebase object level as it requires proper
    // decoding depending on the type. (e.g. it cannot say oldValue: AnyObject, as it's not Codable)
    var oldValue: IntOrStringOrDate?
    var newValue: IntOrStringOrDate?

    func upsertCommand(id: String) throws -> Command {
        guard parentType == "Collaboration" else {
            throw "parentType not supported: \(parentType)"
        }
        // select the field from supported Update.Field
        let uploadField = try Update.Field.allCases.first { $0.rawValue == field }
            .or(error: ModelError.fieldNotSupported(field))
        return AddUpdateCommand(
            updateId: id,
            parentId: parentId,
            parentType: parentType,
            timestamp: timestamp.dateValue(),
            userId: userId,
            field: uploadField,
            oldValue: oldValue,
            newValue: newValue
        )
    }
}
