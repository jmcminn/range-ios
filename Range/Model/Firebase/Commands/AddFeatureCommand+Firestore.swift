import FirebaseFirestore
import Foundation

extension AddFeatureCommand: FirestoreCommand {
    func applyToFirestore(inTransaction transaction: Transaction, context: ProjectModelFirestoreContext) throws {
        let firestoreFeature = FirebaseFeature(geometryId: geometryId, name: name, description: featureDescription)
        try transaction.setData(
            from: firestoreFeature,
            forDocument: context.featuresRef.document(featureId)
        )
    }
}
