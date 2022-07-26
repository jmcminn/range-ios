import FirebaseFirestore
import FirebaseFirestoreSwift
import Foundation

/// A protocol for commands that can be applied to Firestore.
protocol FirestoreCommand {
    /// Apply the changes in a Firestore transaction
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws
}
