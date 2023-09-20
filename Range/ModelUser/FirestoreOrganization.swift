import Foundation
import RealmSwift

/// Represents the `Organization`` (`organizations/` path in Firestore)
struct FirestoreOrganization: Codable, FirestoreToRealmSyncable {
    typealias ModelType = Organization

    /// name
    var name: String
    /// address
    var projectIds: [String]

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case name, projectIds = "projects"
    }

    func upsert(withId id: String, inRealm realm: Realm) throws {
        let organization = Organization(id: id, name: name, projectIds: projectIds)
        realm.add(organization, update: .modified)
    }
}
