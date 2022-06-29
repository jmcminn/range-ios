import Foundation
import RealmSwift

protocol FirebaseCommand {
    func applyToFirebase(firebaseSync: ProjectModelFirebaseSync, in realm: Realm) async throws
}

protocol FirestoreCommand {
    func applyToFirestore(
        firestoreSync: ProjectModelFirestoreSync,
        writer: ProjectModelWriter
    ) async throws
}
