import FirebaseFirestore
import Foundation

/// Apply the `Comment` update in Firestore.
extension UpdateNoteCompletedCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        transaction.updateData(
            [
                FirebaseComment.CodingKeys.completedById.rawValue: completedById ?? FieldValue.delete(),
                FirebaseComment.CodingKeys.completedTimestamp.rawValue: completedTimestamp != nil
                    ? Timestamp(date: completedTimestamp!)
                    : FieldValue.delete(),
            ],
            forDocument: context.commentsRef.document(noteId)
        )
    }
}
