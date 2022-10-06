import FirebaseFirestore
import Foundation

/// Apply the `Upload.tags` update in Firestore.
extension UpdateUploadTagsCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        transaction.updateData(
            [FirebaseUpload.CodingKeys.tagIds.rawValue: tagIds],
            forDocument: context.uploadsRef.document(uploadId)
        )
    }
}
