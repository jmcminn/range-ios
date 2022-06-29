import Foundation
import RealmSwift

extension AddUploadCommand: FirestoreCommand {
    func applyToFirestore(
        firestoreSync _: ProjectModelFirestoreSync,
        writer _: ProjectModelWriter
    ) async throws {}
}

extension AddUploadCommand: FirebaseCommand {
    // TODO: 44 from write perspective the operations are:
    // 1. create new tags
    // 2. add photo to storage
    // 3. create the upload
    func applyToFirebase(firebaseSync _: ProjectModelFirebaseSync, in _: Realm) async throws {}
}
