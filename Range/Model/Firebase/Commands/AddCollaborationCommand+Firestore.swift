import FirebaseFirestore
import Foundation

/// Apply the `Collaboration` add/update in Firestore.
extension AddCollaborationCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
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
