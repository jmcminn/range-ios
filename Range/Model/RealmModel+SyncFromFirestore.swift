import FirebaseFirestore
import FirebaseFirestoreSwift
import Foundation
import OSLog
import RealmSwift

/// Protocol to be adopted by firestore objects that can be stored in Realm
protocol FirestoreToRealmSyncable {
    /// The type used to store the objects in the model Realm db
    associatedtype ModelType: Object & WithId
    /// Upsert this element with given id to given Realm. Will be performed in a realm write transaction
    func upsert(withId id: String, inRealm realm: Realm) throws
}

/// Protocol for firestore objects that need a custom delete method (instead of doing realm.delete(object) when removed from Firestore)
protocol FirestoreToRealmSyncableWithCustomDelete {
    /// Run instead of realm.delete on given object. The implementing method can still decide to realm.delete(object)
    func customDelete(object: Object, inRealm realm: Realm)
}

/// Extend RealmModel with sync from Firestore function
extension RealmModel {
    /// Applies the changes from document to Realm
    /// Catches all errors and log them, does not throw.
    /// It needs to be run in realm.write transaction
    private func apply<T: Decodable & FirestoreToRealmSyncable>(
        documentChangeType changeType: DocumentChangeType,
        snapshot: DocumentSnapshot,
        as type: T.Type,
        inRealm realm: Realm
    ) {
        let decoder = Firestore.Decoder()

        let collectionId = snapshot.reference.parent.collectionID
        let documentId = snapshot.documentID
        Logger.firestore.debug("\(collectionId) \(changeType) \(documentId, privacy: .public)")
        do {
            let firestoreObject = try snapshot.data(as: type, decoder: decoder)
            if changeType == .added || changeType == .modified {
                // get local modifications for this document
                let localCommands = localCommandsProvider?(documentId) ?? []
                let deletedLocally = localCommands.contains { $0.type == .delete }
                // skip updates for locally deleted objects
                guard !deletedLocally else {
                    Logger.firestore.debug(
                        "ignored locally deleted \(collectionId) \(changeType) \(documentId, privacy: .public)"
                    )
                    return
                }
                try firestoreObject.upsert(withId: documentId, inRealm: realm)
                // apply local changes on top of objects received from Firestore. We need to reapply
                // these changes as on each start the changes cached by Firestore SDK may overwrite the local
                // changes if they were not synced yet. (so the Firestore has a different data than the Realm,
                // the difference is provided by given LocalCommands)
                let localUpdates = localCommands.filter { $0.type == .update }
                if !localUpdates.isEmpty {
                    Logger.firestore.debug(
                        "apply local updates for \(collectionId) \(changeType) \(documentId, privacy: .public)"
                    )
                    try localUpdates.forEach { try $0.apply(inRealm: realm) }
                }
            } else if changeType == .removed {
                guard let object = realm.object(ofType: type.ModelType, forPrimaryKey: documentId)
                else {
                    return
                }
                if let firestoreObjectWithCustomDelete =
                    firestoreObject as? FirestoreToRealmSyncableWithCustomDelete
                {
                    firestoreObjectWithCustomDelete.customDelete(object: object, inRealm: realm)
                } else {
                    realm.delete(object)
                }
            } else {
                throw "Change type \(changeType) not handled"
            }
        } catch let DecodingError.dataCorrupted(context),
                    let DecodingError.keyNotFound(_, context),
                    let DecodingError.valueNotFound(_, context),
                    let DecodingError.typeMismatch(_, context) {
            Logger.firestore.error(
                "\(collectionId) decode failed [\(documentId, privacy: .public)]: \(context.debugDescription, privacy: .public)"
            )
        } catch {
            Logger.firestore.error(
                "\(collectionId) \(changeType) failed [\(documentId, privacy: .public)]: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Convenience function to delete local object for given document reference if it exists.
    private func deleteObject<T: Decodable & FirestoreToRealmSyncable>(
        _ documentRef: DocumentReference, as type: T.Type, inRealm realm: Realm
    ) {
        do {
            try realm.write {
                if let object = realm.object(
                    ofType: type.ModelType,
                    forPrimaryKey: documentRef.documentID
                ) {
                    realm.delete(object)
                }
            }
        } catch {
            let loggingId = "\(documentRef.parent.collectionID)/\(documentRef.documentID)"
            Logger.firestore
                .error(
                    "\(loggingId) removing local object failed: \(error.localizedDescription)"
                )
        }
    }

    /// Convenience function to register listener for given Document reference and invoke FirestoreToRealmSyncable method on decoded object to update the Realm state.
    ///  - Parameters:
    ///     - documentRef:  the document to observe updates
    ///     - type: the type to use for decoding the firestore SnapshotData for given db reference
    func sync<T: Decodable & FirestoreToRealmSyncable>(_ documentRef: DocumentReference,
                                                       as type: T.Type) -> ListenerRegistration
    {
        let loggingId = "\(documentRef.parent.collectionID)/\(documentRef.documentID)"
        let listenerRegistration = documentRef.addSnapshotListener { [weak self] documentSnapshot, error in
            guard let self = self else { return }
            self.writeQueue.async {
                guard let snapshot = documentSnapshot else {
                    Logger.firestore.info(
                        "\(loggingId) fetching snapshot failed, removing local object: \(error!.localizedDescription)"
                    )
                    self.deleteObject(documentRef, as: type, inRealm: self.writeRealm)
                    return
                }
                guard snapshot.data() != nil else {
                    Logger.firestore.info("\(loggingId) fetched no data, removing local object")
                    self.deleteObject(documentRef, as: type, inRealm: self.writeRealm)
                    return
                }
                let changeType: DocumentChangeType = .modified
                do {
                    try self.writeRealm.write {
                        self.apply(
                            documentChangeType: changeType,
                            snapshot: snapshot,
                            as: type,
                            inRealm: self.writeRealm
                        )
                    }
                } catch {
                    Logger.firestore.error(
                        "\(loggingId) \(changeType) failed: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }

        return listenerRegistration
    }

    /// Convenience function to register listener for given Collection reference and invoke FirestoreToRealmSyncable methods on decoded objects to update the Realm state.
    ///  - Parameters:
    ///     - collectionRef:  the collection to observe for .childAdded, .childChanged and .childRemoved
    ///     - type: the type to use for decoding the firestore SnapshotData for given db reference
    func sync<T: Decodable & FirestoreToRealmSyncable>(_ collectionRef: CollectionReference,
                                                       as type: T.Type) -> ListenerRegistration
    {
        let listenerRegistration = collectionRef
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] querySnapshot, error in
                guard let self = self else { return }
                guard let snapshot = querySnapshot else {
                    Logger.firestore.error(
                        "\(collectionRef.path) fetching snapshots failed: \(error!.localizedDescription)"
                    )
                    return
                }
                // write all the changes for given collection in one transaction. This makes
                // it much faster when getting the initial data with all the documents
                self.writeQueue.async {
                    do {
                        try self.writeRealm.write {
                            snapshot.documentChanges.forEach { diff in
                                let document = diff.document
                                let changeType = diff.type
                                self.apply(
                                    documentChangeType: changeType,
                                    snapshot: document,
                                    as: type,
                                    inRealm: self.writeRealm
                                )
                            }
                        }
                    } catch {
                        Logger.firestore.error(
                            "\(collectionRef.path) write failed: \(error.localizedDescription)"
                        )
                    }
                }
            }
        return listenerRegistration
    }

    /// Upsert all given documents.
    /// Remove from local db any documents that are not present in given list
    func replaceDocuments<T: Decodable & FirestoreToRealmSyncable>(
        with documents: [QueryDocumentSnapshot],
        as type: T.Type,
        inRealm realm: Realm
    ) {
        documents.forEach {
            // failing to load some documents shouldn't fail the whole sync
            let documentId = $0.documentID
            let collectionId = $0.reference.parent.collectionID
            do {
                let firestoreObject = try $0.data(as: type)
                try firestoreObject.upsert(withId: documentId, inRealm: realm)
            } catch let DecodingError.dataCorrupted(context),
                        let DecodingError.keyNotFound(_, context),
                        let DecodingError.valueNotFound(_, context),
                        let DecodingError.typeMismatch(_, context) {
                Logger.firestore.error(
                    "\(collectionId) sync decode failed [\(documentId, privacy: .public)]: \(context.debugDescription, privacy: .public)"
                )
            } catch {
                Logger.firestore.error(
                    "\(collectionId) upsert failed [\(documentId, privacy: .public)]: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        /// for fast lookup
        let newObjectsIds = Set(documents.map(\.documentID))
        /// delete all objects from local db that are not in documents
        for oldObject in realm.objects(type.ModelType) {
            if !newObjectsIds.contains(oldObject.id) {
                Logger.firestore
                    .debug(
                        "\(type.ModelType.description()) removed \(oldObject.id, privacy: .public) when replacing documents"
                    )
                realm.delete(oldObject)
            }
        }
    }
}
