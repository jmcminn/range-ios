import FirebaseFirestore
import Foundation

/// Add the `Feature` in Firestore.
extension AddFeatureCommand: FirestoreCommand {
    func apply(inFirestoreTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        let firestoreFeature = FirebaseFeature(geometryId: geometryId, name: name, description: featureDescription)
        try transaction.setData(
            from: firestoreFeature,
            forDocument: context.featuresRef.document(featureId)
        )
    }
}
