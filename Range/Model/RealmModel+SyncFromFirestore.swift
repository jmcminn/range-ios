import FirebaseFirestore
import FirebaseFirestoreSwift
import Foundation
import OSLog
import RealmSwift

/// Protocol to be adopted by firestore objects that can be stored in Realm
protocol FirestoreToRealmSyncable {
    /// The type used to store the objects in the model Realm db
    associatedtype ModelType: Object
    /// Upsert this element with given id to given Realm. Will be performed in a realm write transaction
    func upsert(withId id: String, inRealm realm: Realm) throws
}

/// Extend RealmModel with sync from Firestore function
extension RealmModel {
    /// Applies the changes from document to Realm
    /// Catches all errors and log them, does not throw.
    private func apply<T: Decodable & FirestoreToRealmSyncable>(
        documentChangeType changeType: DocumentChangeType,
        snapshot: DocumentSnapshot,
        fromCache: Bool,
        as type: T.Type,
        inRealm realm: Realm
    ) {
        let decoder = Firestore.Decoder()

        let collectionId = snapshot.reference.parent.collectionID
        let documentId = snapshot.documentID
        Logger.firestore.debug(
            "\(collectionId) \(changeType) \(documentId, privacy: .public) \(fromCache ? "(fromCache)" : "")"
        )
        do {
            let firestoreObject = try snapshot.data(as: type, decoder: decoder)
            try realm.write {
                if changeType == .added || changeType == .modified {
                    try firestoreObject.upsert(withId: snapshot.documentID, inRealm: realm)
                } else if changeType == .removed {
                    guard let object = realm.object(ofType: type.ModelType, forPrimaryKey: snapshot.documentID)
                    else {
                        return
                    }
                    realm.delete(object)
                } else {
                    throw "Change type \(changeType) not handled"
                }
            }
        } catch let DecodingError.dataCorrupted(context),
                    let DecodingError.keyNotFound(_, context),
                    let DecodingError.valueNotFound(_, context),
                    let DecodingError.typeMismatch(_, context)
        {
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
    ///     - allowFromCache: should sync update the data if the snapshot is from local Firestore SDK cache? `false` by default to not overwrite any local pending changes. Use `true` only in cases where no local changes are possible
    func sync<T: Decodable & FirestoreToRealmSyncable>(
        _ documentRef: DocumentReference,
        as type: T.Type,
        allowFromCache: Bool = false
    ) -> ListenerRegistration {
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

                // if we don't allow changes from cache then guard against changes being not from cache
                let fromCache = snapshot.metadata.isFromCache
                if !allowFromCache {
                    guard !fromCache else {
                        // we don't want data from cache. Firestore will report all local objects when the app
                        // is starting even in offline mode (because it has persistence enabled, see AppDelegate
                        // Firestore config comment for why it has to be enabled).
                        // This data from cache is not needed, because we have it in Realm and would override
                        // any local pending changes. So it would flicker but for a potentially very long time:
                        // From the time user restarted the app in offline after making local changes until the user is back online.
                        return
                    }
                }
                guard snapshot.data() != nil else {
                    Logger.firestore.info("\(loggingId) fetched no data, removing local object")
                    self.deleteObject(documentRef, as: type, inRealm: self.writeRealm)
                    return
                }
                let changeType: DocumentChangeType = .modified
                self.apply(
                    documentChangeType: changeType,
                    snapshot: snapshot,
                    fromCache: fromCache,
                    as: type,
                    inRealm: self.writeRealm
                )
            }
        }

        return listenerRegistration
    }

    /// Convenience function to register listener for given Collection reference and invoke FirestoreToRealmSyncable methods on decoded objects to update the Realm state.
    ///  - Parameters:
    ///     - collectionRef:  the collection to observe for .childAdded, .childChanged and .childRemoved
    ///     - type: the type to use for decoding the firestore SnapshotData for given db reference
    func sync<T: Decodable & FirestoreToRealmSyncable>(
        _ collectionRef: CollectionReference,
        as type: T.Type
    ) -> ListenerRegistration {
        let listenerRegistration = collectionRef.addSnapshotListener { [weak self] querySnapshot, error in
            guard let self = self else { return }
            guard let snapshot = querySnapshot else {
                Logger.firestore.error(
                    "\(collectionRef.collectionID) fetching snapshots failed: \(error!.localizedDescription)"
                )
                return
            }

            let fromCache = snapshot.metadata.isFromCache
            self.writeQueue.async {
                snapshot.documentChanges.forEach { diff in
                    let document = diff.document
                    let changeType = diff.type

                    if fromCache {
                        // we don't want data from cache. Firestore will report all local objects when the app
                        // is starting even in offline mode (because it has persistence enabled, see AppDelegate
                        // Firestore config comment for why it has to be enabled).
                        // This data from cache is not needed, because we have it in Realm and would override
                        // any local pending changes. So it would flicker but for a potentially very long time:
                        // From the time user restarted the app in offline after making local changes until the user is back online.
                        //
                        // There's one exception - we observed that sometimes deletes are reported
                        // as "from cache" but shouldn't be. It looks like deletes are safe to
                        // proceed no mater if from cache or not. Once deleted the object cannot have
                        // local changes anyway
                        if changeType == .removed {
                            self.apply(
                                documentChangeType: changeType,
                                snapshot: document,
                                fromCache: fromCache,
                                as: type,
                                inRealm: self.writeRealm
                            )
                            // uncomment to see logs about ignored changes from cache
//                        } else {
//                            let collectionId = document.reference.parent.collectionID
//                            let documentId = document.documentID
//                            Logger.firestore
//                                .debug(
//                                    "ignored fromCache \(collectionId) \(changeType) \(documentId, privacy: .public)"
//                                )
                        }
                    } else {
                        self.apply(
                            documentChangeType: changeType,
                            snapshot: document,
                            fromCache: fromCache,
                            as: type,
                            inRealm: self.writeRealm
                        )
                    }
                }
            }
        }
        return listenerRegistration
    }
}
