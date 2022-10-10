import FirebaseFirestore
import Foundation

/// Apply the `Collaboration.name` update in Firestore.
extension UpdateCollaborationNameCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        transaction.updateData(
            [FirebaseCollaboration.CodingKeys.name.rawValue: name],
            forDocument: context.collaborationsRef.document(collaborationId)
        )
    }
}
