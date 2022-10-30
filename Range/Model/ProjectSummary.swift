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
    /// project time zone
    // TODO: should be read from Firestore when it's implemented there
    // to be based on TZ Database name column from https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
    var timeZone: TimeZone = .init(identifier: "America/Los_Angeles") ?? TimeZone.current

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
