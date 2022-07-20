import Foundation
import RealmSwift

extension AddUploadCommand: FirestoreCommand {
    // TODO: 44 from write perspective the operations are:
    // 1. create new tags
    // 2. add photo to storage
    // 3. create the upload
    func applyToFirestore(
        firestoreSync _: ProjectModelFirestoreSync,
        writer _: ProjectModelWriter
    ) async throws {}
}
