import Foundation

/// Represents the Geometry.
///
/// It may contain GeoJSON geometries with different types.
///
/// - Warning: Currently only the point GeoJSON geometry is supported
///
/// Encoded as:
///
///     {
///         "id"       : "0521fccf-3799-4786-aab1-e5e5108c0807",
///         "geometry" : {
///             "type"      : "Point",
///             "coordinates": [-96.77546339604037, 32.82483564429168],
///         }
///     }
struct Geometry: Identifiable, Codable {
    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case id
        case geoJSONGeometry = "geometry"
    }

    /// Defines GeoJSONGeometry types supported by Geometry
    enum GeoJSONGeometry {
        case point(GeoJSONPointGeometry)
    }

    /// UUID identifier of geometry
    let id: String
    /// GeoJSON geometry
    let geoJSONGeometry: GeoJSONGeometry

    /// Constructor for the point geometry
    init(id: String, pointGeometry: GeoJSONPointGeometry) {
        self.id = id
        geoJSONGeometry = .point(pointGeometry)
    }

    /// Custom implementation of decoding that handles different geometry types
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        geoJSONGeometry = try GeoJSONGeometry
            .point(container.decode(GeoJSONPointGeometry.self, forKey: .geoJSONGeometry))
    }

    /// Custom implementation of encoding that handles different geometry types
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        switch geoJSONGeometry {
        case let .point(geoJSONPointGeometry):
            try container.encode(geoJSONPointGeometry, forKey: .geoJSONGeometry)
        }
    }
}
