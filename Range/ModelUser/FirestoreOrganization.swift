import Foundation
import RealmSwift

/// Represents the `Organization`` (`organizations/` path in Firestore)
struct FirestoreOrganization: Codable, FirestoreToRealmSyncable {
    typealias ModelType = Organization

    /// name
    var name: String
    /// industry
    var industry: String
    /// icon
    var icon: String?
    /// address
    var projectIds: [String]

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case name, industry, icon, projectIds = "projects"
    }

    func upsert(withId id: String, inRealm realm: Realm) throws {
        let organization = Organization(id: id, name: name, industry: industry, icon: icon, projectIds: projectIds)
        realm.add(organization, update: .modified)
    }
}
