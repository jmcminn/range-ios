import CoreLocation
import Foundation
import RealmSwift

/// Represents the `ProjectSummary`` (`projects/` path in Firestore)
/// Allows for decoding and storing the decoded object in Realm
/// There's no support for encoding currently as it's a readonly data
/// This struct exists because conformance to `Decodable` cannot be added in class extension and we don't want to polute Realm model with Firebase related logic.
struct FirebaseProjectSummary: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = ProjectSummary

    /// center
    var center: CLLocationCoordinate2D

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case center
    }

    /// Custom implementation of decoding that checks for proper type and translates the `coordinates` array into `position`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var coordinatesContainer = try container.nestedUnkeyedContainer(forKey: .center)
        let longitude = try coordinatesContainer.decode(Double.self)
        let latitude = try coordinatesContainer.decode(Double.self)
        center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(id, forKey: .id)
//        var coordinatesContainer = container.nestedUnkeyedContainer(forKey: .center)
//        try coordinatesContainer.encode(center.longitude)
//        try coordinatesContainer.encode(center.latitude)
//    }

    func upsertCommand(id: String) throws -> Command {
        AddProjectSummaryCommand(projectId: id, center: center)
    }
}
