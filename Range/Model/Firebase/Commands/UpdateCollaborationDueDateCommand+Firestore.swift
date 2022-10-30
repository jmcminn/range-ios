import FirebaseFirestore
import Foundation

/// Apply the `Collaboration.dueDateTimestamp` update in Firestore.
extension UpdateCollaborationDueDateCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        transaction.updateData(
            [FirebaseCollaboration.CodingKeys.dueDateTimestamp.rawValue: dueDateTimestamp != nil
                ? Int(dueDateTimestamp! * 1000)
                : FieldValue.delete()],
            forDocument: context.collaborationsRef.document(collaborationId)
        )
    }
}
