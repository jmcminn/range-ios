import FirebaseFirestore
import Foundation

/// Apply the `Collaboration.tags` update in Firestore.
extension UpdateCollaborationTagsCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        transaction.updateData(
            [FirebaseCollaboration.CodingKeys.tagIds.rawValue: tagIds],
            forDocument: context.collaborationsRef.document(collaborationId)
        )
    }
}
