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
            id: geometryId,
            canvasId: canvasId,
            geometry: .point(Point(coordinates))
        )
        let feature = FirebaseFeature(id: featureId, geometryId: geometryId, name: "")
        let collaboration = FirebaseCollaboration(
            id: collaborationId,
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
                .setData(geometryData, forDocument: sync.geometriesRef.document(geometry.id))
                .setData(featureData, forDocument: sync.featuresRef.document(feature.id))
                .setData(
                    collaborationData,
                    forDocument: sync.collaborationsRef.document(collaboration.id)
                )
        }
    }
}

extension CreatePhotoMarkerCommand: FirebaseCommand {
    // TODO: 44 from write perspective the operations are:
    // 1. created geometry
    // 2. created feature
    // 3. created collaboration
    func applyToFirebase(firebaseSync: ProjectModelFirebaseSync, in _: Realm) async throws {
        // swiftformatter collides with logging when using "self.collaborationId"
//        let id = collaborationId
//        guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) else {
//            Logger.firebase.warning(
//                "collaboration \(id, privacy: .public) not found when saving to firebase"
//            )
//            return
//        }
//        guard let feature = collaboration.feature.first else {
//            Logger.firebase.warning(
//                "feature for collaboration \(id, privacy: .public) not found when saving to firebase"
//            )
//            return
//        }
//        guard let geometry = feature.geometry.first else {
//            Logger.firebase.warning(
//                "geometry for collaboration \(id, privacy: .public) not found when saving to firebase"
//            )
//            return
//        }
        let geometryId = "bad id"
//        let geometryId = geometryId

        let firebaseGeometry = FirebaseGeometry(
            id: geometryId,
            canvasId: canvasId,
            geometry: .point(Point(coordinates))
        )
        let firebaseFeature = FirebaseFeature(id: featureId, geometryId: geometryId, name: "")
        let firebaseCollaboration = FirebaseCollaboration(
            id: collaborationId,
            featureId: featureId,
            statusId: nil,
            name: "",
            description: "",
            tagIds: []
        )
        Logger.firebase.info("Adding geometry \(geometryId)")
        let encoded = try FirebaseDataEncoder().encode(firebaseGeometry)
        firebaseSync.geometriesReference.child(geometryId).runTransactionBlock({ currentData in
            currentData.value = encoded
            return TransactionResult.success(withValue: currentData)

        }, andCompletionBlock: { error, _, _ in
            print("xxx error: ", error)
            Logger.firebase.info("Sync error: \(error != nil)")
        }, withLocalEvents: true)
//        try firebaseSync.geometriesReference.child(geometryId).setValue(from: firebaseGeometry, completion: { error in
//            Logger.firebase.info("Sync error: \(error != nil)")
//        })
//        try firebaseSync.featuresReference.child(featureId).setValue(from: firebaseFeature)
//        try firebaseSync.collaborationsReference.child(collaborationId).setValue(from: firebaseCollaboration)
    }
}
