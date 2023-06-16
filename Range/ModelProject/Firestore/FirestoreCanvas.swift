import Foundation
import RealmSwift

/// Represents the ``Canvas`` (`projects/canvases` path in Firestore)
/// There's no support for encoding currently as it's a readonly data
struct FirestoreCanvas: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = Canvas

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case name
    }

    var name: String

    func upsert(withId id: String, inRealm realm: Realm) throws {
        let canvas = Canvas(id: id, name: name)
        realm.add(canvas, update: .modified)
    }
}
