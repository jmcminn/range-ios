import FirebaseFirestore
import Foundation

/// Apply the `Comment` update in Firestore.
extension UpdateCommentTextCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        transaction.updateData(
            [
                FirebaseComment.CodingKeys.text.rawValue: text,
                FirebaseComment.CodingKeys.textIsEdited.rawValue: true,
            ],
            forDocument: context.commentsRef.document(commentId)
        )
    }
}
