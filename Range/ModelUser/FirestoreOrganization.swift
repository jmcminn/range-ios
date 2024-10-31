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
    //    billingError: {
    //        type: event.type,
    //        priority: BILLING_ERROR_PRIORITIES.CARD_DECLINED,
    //        timestamp: Date.now(),
    //        gracePeriodEndsTimestamp: Date.now() + 7 * 24 * 60 * 60 * 1000, // default is 7 days from now
    //    },
    var billingError: JSON?

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case billingError, icon, industry, isDisabled, limitsAndCounts, name, plan, projectIds = "projects"
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
            isDisabled: isDisabled ?? false,
            billingErrorGracePeriodEnd: billingError?["gracePeriodEndsTimestamp"]?.dateValue
        )
        realm.add(organization, update: .modified)
    }
}
