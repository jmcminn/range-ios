import FirebaseFirestore
import Foundation

/// Apply the `Upload` add/update in Firestore.
extension AddUploadCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        let firestoreObject = FirebaseUpload(
            parentId: parentId,
            parentType: parentType,
            authorId: authorId,
            timestamp: Int(timestamp),
            name: name,
            uploadDescription: uploadDescription,
            urlString: url?.absoluteString,
            correlationId: correlationId,
            tagIds: tagIds
        )
        try transaction.setData(
            from: firestoreObject,
            forDocument: context.uploadsRef.document(uploadId)
        )
    }
}
