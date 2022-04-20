import CoreLocation
import Foundation

/// Represents the GeoJSON point.
///
/// Its encoded form has a `type` of "Point" and stores the `position` as an array of `[longitude, latitude]`
///
///     {
///       "type"       : "Point",
///       "coordinates": [-96.77546339604037, 32.82483564429168],
///     }
struct GeoJSONPointGeometry: Codable {
    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case type
        case coordinates
    }

    /// The type of geometry
    private let type = "Point"

    /// The Geo position of this geometry
    let position: CLLocationCoordinate2D

    /// Initiate with position
    init(position: CLLocationCoordinate2D) {
        self.position = position
    }

    /// Custom implementation of decoding that checks for proper type and translates the `coordinates` array into `position`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        if type != self.type {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unsupported type")
        }
        var coordinatesContainer = try container.nestedUnkeyedContainer(forKey: .coordinates)
        let longitude = try coordinatesContainer.decode(Double.self)
        let latitude = try coordinatesContainer.decode(Double.self)
        position = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Custom implementation of encoding that sets `type` to "Point" and `coordinates` to array based on the `position`
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(type, forKey: .type)

        var coordinatesContainer = container.nestedUnkeyedContainer(forKey: .coordinates)
        try coordinatesContainer.encode(position.longitude)
        try coordinatesContainer.encode(position.latitude)
    }
}
