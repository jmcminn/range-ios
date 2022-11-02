import FirebaseFirestore
import Foundation

/// Add the `Update` in Firestore.
extension AddUpdateCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        let firestoreObject = FirebaseUpdate(
            parentId: parentId,
            parentType: parentType,
            timestamp: Timestamp(date: timestamp),
            userId: userId,
            field: field.rawValue,
            oldValue: oldValue,
            newValue: newValue
        )

        var data = try Firestore.Encoder().encode(firestoreObject)

        // overwrite timestamp with serverTimestamp - we want the Firestore to set
        // its current timestamp when creating the `Update`
        data[FirebaseUpdate.CodingKeys.timestamp.rawValue] = FieldValue.serverTimestamp()

        transaction.setData(data, forDocument: context.updatesRef.document(updateId))
    }
}
