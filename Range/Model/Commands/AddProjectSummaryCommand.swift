import CoreLocation
import Foundation
import RealmSwift

struct AddProjectSummaryCommand: Command {
    let projectId: String
    let center: CLLocationCoordinate2D

    /// Adds or updates project summary in the Realm database
    func apply(inRealm realm: Realm) throws {
        let projectSummary = ProjectSummary(id: projectId, center: center)
        realm.add(projectSummary, update: .modified)
    }
}
