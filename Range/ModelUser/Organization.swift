import Foundation
import RealmSwift
import UIKit

/// Realm object for `organizations`.
class Organization: Object, WithId {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// Organization name
    @Persisted var name: String
    /// Organization industry
    @Persisted var industry: String
    /// base64 encoded icon
    @Persisted var icon: String?
    /// array of all projects ids of this organization (user may not have access to all of them)
    @Persisted var projectIds: List<String>
    /// Organization Plan, iOS doesn't care about the actual plan so it's a String and not enum (only to be displayed in UI)
    /// Optional so the current offline data doesn't need migration
    @Persisted var plan: String?
    //
    //         int    collaborationCountLimit
    //         int    uploadCountLimit
    //         int    uploadStorageBytesLimit
    //         int    userAndInvitationCountLimit
    //
    //         int    collaborationCount
    //         int    uploadCount
    //         int    uploadStorageBytesCount
    //         int    userAndInvitationCount
    @Persisted var limitsAndCounts: Map<String, Int64>
    /// whether the organization is disabled and the whole UI for this org should be blocked
    @Persisted var isDisabled: Bool
    /// billingError.gracePeriodEndsTimestamp - when present it means that a billing error is currently present for this organization
    /// and that its grace periods ends at given date.... after this date the organization is considered disabled (although the isDisabled
    /// flag might not necessarily be set to true).
    @Persisted var billingErrorGracePeriodEnd: Date?
    /// By default (if absent) we treat errors as priority 1
    /// See BILLING_ERROR_PRIORITIES in the backend. Priority 1 is CARD_DECLINED
    @Persisted var billingErrorPriority: Int?

    /// This should only be called if there's a billing error recognized, which should be based on the presence of the
    /// billingErrorGracePeriodEnd
    var isCardDeclinedBillingError: Bool {
        if let billingErrorPriority, billingErrorPriority != 1 { return false }
        return true
    }

    var isBlockedDueToBillingError: Bool {
        guard let billingErrorGracePeriodEnd else { return false }
        return billingErrorGracePeriodEnd < Date()
    }

    lazy var iconImage: UIImage? = icon
        .flatMap { URL(string: $0) }
        .flatMap { try? Data(contentsOf: $0) }
        .flatMap { UIImage(data: $0) }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(
        id: String,
        name: String,
        industry: String,
        icon: String? = nil,
        plan: String,
        projectIds: [String] = [],
        limitsAndCounts: [String: Int64] = [:],
        isDisabled: Bool = false,
        billingErrorGracePeriodEnd: Date? = nil,
        billingErrorPriority: Int? = nil
    ) {
        super.init()
        self.id = id
        self.name = name
        self.industry = industry
        self.icon = icon
        self.plan = plan
        self.projectIds.append(objectsIn: projectIds)
        self.limitsAndCounts.merge(limitsAndCounts) { _, new in new }
        self.isDisabled = isDisabled
        self.billingErrorGracePeriodEnd = billingErrorGracePeriodEnd
        self.billingErrorPriority = billingErrorPriority
    }

    /// Equality based on id
    override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? Organization else { return false }
        if id != rhs.id { return false }
        return true
    }
}
