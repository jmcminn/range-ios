import Foundation
import RealmSwift

/// Realm object for `organizations`.
class Organization: Object, WithId {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// Organization name
    @Persisted var name: String
    /// projects for this organization (the ones that the user has access to), the order doesn't matter so it's a set
    @Persisted var projects: MutableSet<ProjectSummary>

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, name: String) {
        super.init()
        self.id = id
        self.name = name
    }
}
