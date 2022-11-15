import FirebaseFirestore
import Foundation

/// This is not really a command, just a utility method for Update creation in Firestore to be reused in other commands as Updates are never created alone
struct CreateUpdateCommand {
    static func addUpdate(updateId: String, parentId: String, parentType: String, userId: String,
                          field: Update.Field, oldValue: StringOrDate?, newValue: StringOrDate?,
                          inFirestore ctx: FirestoreCommandContext) throws
    {
        let firestoreObject = FirebaseUpdate(
            parentId: parentId,
            parentType: parentType,
            timestamp: Timestamp(), // doesn't matter, set to serverTimestamp on encoded object
            userId: userId,
            field: field.rawValue
        )

        var data = try Firestore.Encoder().encode(firestoreObject)

        // overwrite timestamp with serverTimestamp - we want the Firestore to set
        // its current timestamp when creating the `Update`
        data[FirebaseUpdate.CodingKeys.timestamp.rawValue] = FieldValue.serverTimestamp()

        data[FirebaseUpdate.CodingKeys.oldValue.rawValue] = oldValue?.withDateAsTimestamp
        data[FirebaseUpdate.CodingKeys.newValue.rawValue] = newValue?.withDateAsTimestamp

        ctx.setData(data, forDocument: .update(updateId))
    }
}
