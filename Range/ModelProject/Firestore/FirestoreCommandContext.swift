import FirebaseFirestore
import Foundation

/// A context for firestore commands. It hides the Firestore `Transaction` and instead exposed the functions
/// based on `FirestoreDocument`. This allows to mock the context (and document references) and unit test
/// the firestore commands.
protocol FirestoreCommandContext {
    /// Check if given document exists in Firestore. If the function throws the answer is unknown
    func exists(_ doc: FirestoreDocument) throws -> Bool
    /// Returns document decoded as given type. If it doesn't exist it returns nil. If it fails to get the document or decode it, it throws
    func getDocument<T: Decodable>(_ doc: FirestoreDocument, as _: T.Type) throws -> T?
    func setData(_ data: [String: Any], forDocument doc: FirestoreDocument)
    func setData<T: Encodable>(from value: T, forDocument doc: FirestoreDocument) throws
    func updateData(_ fields: [String: Any], forDocument doc: FirestoreDocument)
    func deleteDocument(_ doc: FirestoreDocument)
}

/// Real implementation of FirestoreCommandContext based on the actual Firestore `Transaction`.
class TransactionalFirestoreCommandContext: FirestoreCommandContext {
    let transaction: Transaction
    let projectRef: DocumentReference

    init(transaction: Transaction, projectRef: DocumentReference) {
        self.transaction = transaction
        self.projectRef = projectRef
    }

    init(transaction: Transaction, firestore: Firestore, projectId: String) {
        self.transaction = transaction
        projectRef = firestore.document("projects/\(projectId)")
    }

    private func docRef(_ doc: FirestoreDocument) -> DocumentReference {
        projectRef.collection(doc.type.rawValue).document(doc.id)
    }

    func exists(_ doc: FirestoreDocument) throws -> Bool {
        try transaction.getDocument(docRef(doc)).exists
    }

    func getDocument<T: Decodable>(_ doc: FirestoreDocument, as _: T.Type) throws -> T? {
        guard try exists(doc) else { return nil }
        let snapshot = try transaction.getDocument(docRef(doc))
        return try snapshot.data(as: T.self)
    }

    func updateData(_ fields: [String: Any], forDocument doc: FirestoreDocument) {
        transaction.updateData(fields, forDocument: docRef(doc))
    }

    func setData(_ data: [String: Any], forDocument doc: FirestoreDocument) {
        transaction.setData(data, forDocument: docRef(doc))
    }

    func setData<T: Encodable>(from value: T, forDocument doc: FirestoreDocument) throws {
        setData(try Firestore.Encoder().encode(value), forDocument: doc)
    }

    func deleteDocument(_ doc: FirestoreDocument) {
        transaction.deleteDocument(docRef(doc))
    }
}
