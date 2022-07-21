import FirebaseFirestore
import FirebaseFirestoreSwift
import Foundation
import RealmSwift

protocol FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws
}
