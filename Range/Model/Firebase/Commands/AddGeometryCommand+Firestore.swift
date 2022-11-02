import FirebaseFirestore
import Foundation

/// Add the `Geometry` in Firestore.
extension AddGeometryCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        let firestoreGeometry = FirebaseGeometry(
            canvasId: canvasId,
            geometry: geometry,
            // TODO: 460 do not provide archivedTimestamp when creating the Geometry in firestore?
            archivedTimestamp: archivedTimestamp != nil ? Timestamp(date: archivedTimestamp!) : nil
        )
        try transaction.setData(
            from: firestoreGeometry,
            forDocument: context.geometriesRef.document(geometryId)
        )
    }
}
