import FirebaseFirestore
import Foundation

/// Add the `Collaboration` in Firestore.
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

        var data = try Firestore.Encoder().encode(firestoreObject)

        data[FirebaseUpdate.CodingKeys.timestamp.rawValue] = FieldValue.serverTimestamp()

        transaction.setData(data, forDocument: context.collaborationsRef.document(collaborationId))
    }
}
