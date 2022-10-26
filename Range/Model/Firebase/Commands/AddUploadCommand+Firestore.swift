import FirebaseFirestore
import Foundation

/// Apply the `Upload` add/update in Firestore.
extension AddUploadCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        let firestoreObject = FirebaseUpload(
            parentId: parentId,
            parentType: parentType,
            authorId: authorId,
            timestamp: Int(timestamp * 1000), // server-side is in milliseconds
            name: name,
            uploadDescription: uploadDescription,
            correlationId: correlationId,
            tagIds: tagIds,
            fileTypeString: fileType.rawValue,
            imageHeightToWidth: imageHeightToWidth
        )
        try transaction.setData(
            from: firestoreObject,
            forDocument: context.uploadsRef.document(uploadId)
        )
    }
}
