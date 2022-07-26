import CoreLocation
import Foundation
import RealmSwift

/// Add or update the `ProjectSummary`.
struct AddProjectSummaryCommand: Command, Equatable {
    let projectId: String
    var center: CLLocationCoordinate2D

    /// Adds or updates project summary in the Realm database
    func apply(inRealm realm: Realm) throws {
        let projectSummary = ProjectSummary(id: projectId, center: center)
        realm.add(projectSummary, update: .modified)
    }
}
