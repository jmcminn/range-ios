import FirebaseFirestore
import Foundation

/// Apply the `Comment` add/update in Firestore.
extension AddCommentCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        let firestoreObject = FirebaseComment(
            parentId: parentId,
            parentType: parentType,
            authorId: authorId,
            timestamp: Int(timestamp * 1000), // server-side is in milliseconds
            text: text,
            textIsEdited: textIsEdited,
            isNote: isNote,
            completedById: completedById,
            completedTimestamp: completedTimestamp != nil ? Int(completedTimestamp! * 1000) : nil
        )
        try transaction.setData(
            from: firestoreObject,
            forDocument: context.commentsRef.document(commentId)
        )
    }
}
