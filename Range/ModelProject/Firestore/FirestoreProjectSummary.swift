import CoreLocation
import Foundation
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

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case center, name, projectDescription = "description", address
    }

    func upsert(withId id: String, inRealm realm: Realm) throws {
        let projectSummary = ProjectSummary(
            id: id,
            name: name,
            center: center.decodedCoordinates,
            description: projectDescription,
            address: address
        )
        realm.add(projectSummary, update: .modified)
    }
}
