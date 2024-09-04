import CoreLocation
import Foundation
import OSLog
import RealmSwift

/// Represents the `ProjectSummary`` (`projects/` path in Firestore)
/// This struct exists because conformance to `Codable` cannot be added in class extension and we don't want to polute Realm model with Firestore related logic.
struct FirestoreProjectSummary: Decodable, FirestoreToRealmSyncable {
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
    /// identifier "1"... or a custom project identifier "M10"...
    var identifier: String?
    /// whether project is archived
    var isArchived: Bool?

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case center, name, projectDescription = "description", address, canvasOrder, projectTypeId = "projectType",
             organizationId = "organization", identifier, isArchived
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
            canvasOrder: canvasOrder ?? [],
            identifier: identifier,
            isArchived: isArchived ?? false
        )
        // preserve the task counts in Realm (they are local only data)
        if let existingProject = realm.object(ofType: ProjectSummary.self, forPrimaryKey: id) {
            existingProject.statusTaskCounts.forEach {
                // need to recreate the embedded objects, cannot add existing ones to new List
                projectSummary.statusTaskCounts.append(StatusTaskCount(
                    id: $0.id, name: $0.name, hexColor: $0.hexColor, taskCount: $0.taskCount
                ))
            }
        }
        realm.add(projectSummary, update: .modified)
    }
}
