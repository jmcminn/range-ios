import CoreLocation
import Foundation
import RealmSwift

/// Realm object for `project/summary`.
class ProjectSummary: Object {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// Project name
    @Persisted var name: String
    /// Center geo location for the project
    @Persisted var center: CLLocationCoordinate2D

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, name: String, center: CLLocationCoordinate2D) {
        super.init()
        self.id = id
        self.name = name
        self.center = center
    }
}
