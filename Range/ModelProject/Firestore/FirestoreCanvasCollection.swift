import Foundation
import RealmSwift

/// Represents the ``CanvasCollection`` (`projects/canvasCollections` path in Firestore)
/// There's no support for encoding currently as it's a readonly data
struct FirestoreCanvasCollection: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = CanvasCollection

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case name, storageVersion
    }

    var name: String
    var storageVersion: [String: String]?

    func upsert(withId id: String, inRealm realm: Realm) throws {
        let storageVersion = storageVersion?["main"]
        let canvasCollection = CanvasCollection(id: id, name: name, storageVersion: storageVersion)
        realm.add(canvasCollection, update: .modified)
    }
}
