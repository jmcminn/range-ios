import FirebaseFirestore
import Foundation

extension AddCollaborationCommand: FirestoreCommand {
    func applyToFirestore(inTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        let firestoreObject = FirebaseCollaboration(
            featureId: featureId,
            statusId: statusId,
            name: name,
            description: collaborationDescription,
            tagIds: tagIds
        )
        try transaction.setData(
            from: firestoreObject,
            forDocument: context.collaborationsRef.document(collaborationId)
        )
    }
}
