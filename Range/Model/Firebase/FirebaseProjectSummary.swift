import CoreLocation
import Foundation

/// Decodable for ``ProjectSummary`` (`projects/summary` path in Firebase)
/// There's no support for encoding currently as it's a readonly data
/// This struct exists because conformance to `Decodable` cannot be added in class extension and we don't want to polute Realm model with Firebase related logic.
struct FirebaseProjectSummary: Decodable {
    /// The decoded projectSummary
    let projectSummary: ProjectSummary

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case id
        case center
    }

    /// Custom implementation of decoding that checks for proper type and translates the `coordinates` array into `position`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        var coordinatesContainer = try container.nestedUnkeyedContainer(forKey: .center)
        let longitude = try coordinatesContainer.decode(Double.self)
        let latitude = try coordinatesContainer.decode(Double.self)
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        projectSummary = ProjectSummary(id: id, center: center)
    }

//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(id, forKey: .id)
//        var coordinatesContainer = container.nestedUnkeyedContainer(forKey: .center)
//        try coordinatesContainer.encode(center.longitude)
//        try coordinatesContainer.encode(center.latitude)
//    }
}
