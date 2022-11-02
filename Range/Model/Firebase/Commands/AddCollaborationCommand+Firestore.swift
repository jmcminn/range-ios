import FirebaseFirestore
import Foundation

/// Apply the `Collaboration` add/update in Firestore.
extension AddCollaborationCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        let firestoreObject = FirebaseCollaboration(
            featureId: featureId,
            authorId: authorId,
            timestamp: Timestamp(date: timestamp),
            statusId: statusId,
            name: name,
            collaborationDescription: collaborationDescription,
            tagIds: tagIds,
            assigneeId: assigneeId,
            dueDateTimestamp: dueDateTimestamp != nil ? Timestamp(date: dueDateTimestamp!) : nil
        )
        try transaction.setData(
            from: firestoreObject,
            forDocument: context.collaborationsRef.document(collaborationId)
        )
    }
}
