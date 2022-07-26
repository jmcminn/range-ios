import FirebaseFirestore
import Foundation

/// Apply the `Geometry` add/update in Firestore.
extension AddGeometryCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        let firestoreGeometry = FirebaseGeometry(canvasId: canvasId, geometry: geometry)
        try transaction.setData(
            from: firestoreGeometry,
            forDocument: context.geometriesRef.document(geometryId)
        )
    }
}
