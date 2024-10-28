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
        limitsAndCounts: [String: Int64] = [:]
    ) {
        super.init()
        self.id = id
        self.name = name
        self.industry = industry
        self.icon = icon
        self.plan = plan
        self.projectIds.append(objectsIn: projectIds)
        self.limitsAndCounts.merge(limitsAndCounts) { _, new in new }
    }

    /// Equality based on id
    override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? Organization else { return false }
        if id != rhs.id { return false }
        return true
    }
}
