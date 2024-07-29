import CoreLocation
import FirebaseFirestore
import Foundation
import RealmSwift

/// Represents the `Update` (`projects/updates` path in Firestore)
///
/// Encoded as:
///
///     {
///         "parent": "13083d62-03a1-43d7-8eb0-ca5bb8b357f3",
///         "parentType": "Collaboration",
///         "createdAt": 1649228400000,
///         "createdBy": "9e06df97-aa0f-4e0f-8c78-8892bfb126ec",
///         "field": "name",
///         "oldValue": "name", // optional, type depends on the field
///         "newValue": null // optional, type depends on the field
///     }
struct FirestoreUpdate: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = Update

    /// CodingKeys used by Codable as a keys in the encoded form
    enum CodingKeys: String, CodingKey, CaseIterable {
        case createdById = "createdBy", createdAt,
            field,
            newValue, oldValue,
            parentId = "parent", parentType
    }

    var createdAt: Date
    var createdById: String
    var field: String // allow anything but constrain to supported Update.Field when upserting
    // old and new value can have different types depending on the field. For now Int, String or
    // Date is supported. The support needs to be made on the firebase object level as it requires proper
    // decoding depending on the type. (e.g. it cannot say oldValue: AnyObject, as it's not Codable)
    var newValue: StringOrDate?
    var oldValue: StringOrDate?
    var parentId: String
    var parentType: String

    func upsert(withId id: String, inRealm realm: Realm) throws {
        guard parentType == "Collaboration" else {
            throw "parentType not supported: \(parentType)"
        }
        // select the field from supported Update.Field
        let updateField = try Update.Field.allCases.first { $0.rawValue == field }
            .or(error: ModelError.fieldNotSupported(field))

        let collaboration = realm.objectOrPlaceholder(ofType: Collaboration.self, forPrimaryKey: parentId)
        let user = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: createdById)
        let oldValue: AnyRealmValue = oldValue?.anyRealmValue ?? .none
        let newValue: AnyRealmValue = newValue?.anyRealmValue ?? .none
        let update = Update(id: id, createdAt: createdAt, field: updateField, oldValue: oldValue, newValue: newValue)
        update.user = user
        realm.add(update, update: .modified)
        collaboration.updates.insert(update)
    }
}
