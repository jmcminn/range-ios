import FirebaseDatabase
import FirebaseDatabaseSwift
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseSharedSwift
import Foundation
import OSLog
import RealmSwift
import Turf

extension CreatePhotoMarkerCommand: FirestoreCommand {
    func applyToFirestore(
        firestoreSync sync: ProjectModelFirestoreSync,
        writer _: ProjectModelWriter
    ) async throws {
        let geometry = FirebaseGeometry(
            canvasId: canvasId,
            geometry: .point(Point(coordinates))
        )
        let feature = FirebaseFeature(geometryId: geometryId, name: "")
        let collaboration = FirebaseCollaboration(
            featureId: featureId,
            statusId: nil,
            name: "",
            description: "",
            tagIds: []
        )
        // TODO: 44 no need, the order problem is solved with placeholders?
        // Add them locally, so the order of Firestore updates doesn't matter
//        try await writer.write { realm in
//            try geometry.upsert(realm)
//            try feature.upsert(realm)
//            try collaboration.upsert(realm)
//        }
        // TODO: 44 logs
        let geometryId = geometryId
        Logger.firestore.info("Adding geometry \(geometryId)")
        let geometryData = try Firestore.Encoder().encode(geometry)
        let featureData = try Firestore.Encoder().encode(feature)
        let collaborationData = try Firestore.Encoder().encode(collaboration)
        try await sync.firestore.runTransaction { transaction, _ -> Any? in
            transaction
                .setData(geometryData, forDocument: sync.geometriesRef.document(geometryId))
                .setData(featureData, forDocument: sync.featuresRef.document(self.featureId))
                .setData(
                    collaborationData,
                    forDocument: sync.collaborationsRef.document(self.collaborationId)
                )
        }
    }
}
