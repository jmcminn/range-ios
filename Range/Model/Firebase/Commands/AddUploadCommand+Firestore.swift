import FirebaseFirestore
import Foundation

extension AddUploadCommand: FirestoreCommand {
    func applyToFirestore(inTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        let firestoreObject = FirebaseUpload(
            parentId: parentId,
            parentType: parentType,
            authorId: authorId,
            timestamp: Int(timestamp),
            name: name,
            uploadDescription: uploadDescription,
            urlString: url?.absoluteString,
            correlationId: correlationId
        )
        try transaction.setData(
            from: firestoreObject,
            forDocument: context.uploadsRef.document(uploadId)
        )
    }
}
