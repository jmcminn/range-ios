import CoreLocation
import Foundation
import RealmSwift

/// Add or update the `ProjectSummary` in local Realm db.
struct UpsertProjectSummaryCommand: LocalCommand, Equatable {
    let projectId: String
    var name: String
    var center: CLLocationCoordinate2D

    func apply(inRealm realm: Realm) throws {
        let projectSummary = ProjectSummary(id: projectId, name: name, center: center)
        realm.add(projectSummary, update: .modified)
    }
}
