import Foundation
import RealmSwift

/// Realm object for `organizations`.
class Organization: Object, WithId {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// Organization name
    @Persisted var name: String
    /// array of all projects ids of this organization (user may not have access to all of them)
    @Persisted var projectIds: List<String>

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, name: String, projectIds: [String] = []) {
        super.init()
        self.id = id
        self.name = name
        self.projectIds.append(objectsIn: projectIds)
    }

    /// Equality based on id
    override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? Organization else { return false }
        if id != rhs.id { return false }
        return true
    }
}
