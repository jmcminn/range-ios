import Foundation
import OSLog
import RealmSwift

/// Represents the `Category` in Firestore
struct FirestoreCategory: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = Category

    var name: String
    var iconUrlString: String
    var isDefault: Bool
    var order: Double

    /// CodingKeys used by Codable as a keys in the encoded form
    enum CodingKeys: String, CodingKey {
        case name, iconUrlString = "icon", isDefault, order
    }

    func modelObject(withId id: String) -> ModelType {
        let iconUrl = URL(string: iconUrlString)
        if iconUrl == nil {
            Logger.firestore.log("not well formed icon: \(iconUrlString) for category: \(id)")
        }
        return Category(id: id, name: name, iconUrl: iconUrl, isDefault: isDefault, order: order)
    }

    func upsert(withId id: String, inRealm realm: Realm) throws {
        realm.add(modelObject(withId: id), update: .modified)
    }
}
