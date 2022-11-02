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
        try transaction.setData(
            from: firestoreObject,
            forDocument: context.updatesRef.document(updateId)
        )
    }
}
