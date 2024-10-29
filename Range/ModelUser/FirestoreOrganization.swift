import Foundation
import RealmSwift

/// Represents the `Organization`` (`organizations/` path in Firestore)
struct FirestoreOrganization: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = Organization

    /// name
    var name: String
    /// industry
    var industry: String
    /// icon
    var icon: String?
    /// address
    var projectIds: [String]
    /// plan
    var plan: String
    /// limitsAndCounts
    var limitsAndCounts: [String: Int64]?
    ///
    var isDisabled: Bool?

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case name, industry, icon, isDisabled, limitsAndCounts, plan, projectIds = "projects"
    }

    func upsert(withId id: String, inRealm realm: Realm) throws {
        let organization = Organization(
            id: id,
            name: name,
            industry: industry,
            icon: icon,
            plan: plan,
            projectIds: projectIds,
            limitsAndCounts: limitsAndCounts ?? [:],
            isDisabled: isDisabled ?? false
        )
        realm.add(organization, update: .modified)
    }
}
