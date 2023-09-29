import CoreLocation
import Foundation
import OSLog
import RealmSwift

/// Represents the `ProjectSummary`` (`projects/` path in Firestore)
/// This struct exists because conformance to `Codable` cannot be added in class extension and we don't want to polute Realm model with Firestore related logic.
struct FirestoreProjectSummary: Codable, FirestoreToRealmSyncable {
    typealias ModelType = ProjectSummary

    /// center
    var center: LocationCoordinate2DCodable
    /// name
    var name: String
    /// description
    var projectDescription: String?
    /// address
    var address: String?
    /// UI order of canvases
    var canvasOrder: [String]?
    /// project type
    var projectTypeId: String
    /// organization id
    var organizationId: String

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case center, name, projectDescription = "description", address, canvasOrder, projectTypeId = "projectType",
             organizationId = "organization"
    }

    func upsert(withId id: String, inRealm realm: Realm) throws {
        let projectType: ProjectSummary.ProjectType
        if let type = ProjectSummary.ProjectType(fromId: projectTypeId) {
            projectType = type
        } else {
            Logger.firestore.error("Unknown projectType: \(projectTypeId), using '.other' instead")
            projectType = .other
        }
        let projectSummary = ProjectSummary(
            id: id,
            name: name,
            organizationId: organizationId,
            center: center.decodedCoordinates,
            description: projectDescription,
            address: address,
            projectType: projectType,
            canvasOrder: canvasOrder ?? []
        )
        realm.add(projectSummary, update: .modified)
    }
}
