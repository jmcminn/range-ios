import FirebaseFirestore
import Foundation

/// Add the `Comment` in Firestore.
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
            // TODO: 460 it's never completed when created (?)
            completedTimestamp: completedTimestamp != nil ? Timestamp(date: completedTimestamp!) : nil
        )

        var data = try Firestore.Encoder().encode(firestoreObject)

        data[FirebaseUpdate.CodingKeys.timestamp.rawValue] = FieldValue.serverTimestamp()

        transaction.setData(data, forDocument: context.commentsRef.document(commentId))
    }
}
