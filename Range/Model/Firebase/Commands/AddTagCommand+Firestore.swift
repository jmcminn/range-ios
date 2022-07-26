import FirebaseFirestore
import Foundation

/// Apply the `Tag` add/update in Firestore.
extension AddTagCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        let firestoreObject = FirebaseTagName(name: name)
        try transaction.setData(
            from: firestoreObject,
            forDocument: context.tagNamesRef.document(tagId)
        )
    }
}
