import FirebaseFirestore
import Foundation

/// Apply the `Comment` add/update in Firestore.
extension AddCommentCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        let firestoreObject = FirebaseComment(
            parentId: parentId,
            parentType: parentType,
            authorId: authorId,
            timestamp: Timestamp(date: timestamp),
            text: text,
            textIsEdited: textIsEdited,
            isNote: isNote,
            completedById: completedById,
            completedTimestamp: completedTimestamp != nil ? Timestamp(date: completedTimestamp!) : nil
        )
        try transaction.setData(
            from: firestoreObject,
            forDocument: context.commentsRef.document(commentId)
        )
    }
}
