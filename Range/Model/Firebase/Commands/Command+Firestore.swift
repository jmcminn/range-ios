import Foundation
import RealmSwift

protocol FirestoreCommand {
    func applyToFirestore(
        firestoreSync: ProjectModelFirestoreSync,
        writer: ProjectModelWriter
    ) async throws
}
