import FirebaseFirestore
import FirebaseFirestoreSwift
import Foundation
import RealmSwift

protocol FirestoreCommand {
    func applyToFirestore(inTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws
}
