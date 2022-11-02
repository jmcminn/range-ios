import FirebaseFirestore
import Foundation

/// Add the `Upload` in Firestore.
extension AddUploadCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        let firestoreObject = FirebaseUpload(
            parentId: parentId,
            parentType: parentType,
            authorId: authorId,
            timestamp: Timestamp(date: timestamp),
            name: name,
            uploadDescription: uploadDescription,
            correlationId: correlationId,
            tagIds: tagIds,
            fileTypeString: fileType.rawValue,
            imageHeightToWidth: imageHeightToWidth
        )
        var data = try Firestore.Encoder().encode(firestoreObject)

        data[FirebaseUpdate.CodingKeys.timestamp.rawValue] = FieldValue.serverTimestamp()

        transaction.setData(data, forDocument: context.uploadsRef.document(uploadId))
    }
}
