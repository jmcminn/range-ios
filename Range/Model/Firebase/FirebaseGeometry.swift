import CoreLocation
import Foundation
import RealmSwift
import Turf

/// Represents the `Geometry` (`projects/details/geometries` path in Firebase)
///
/// It may contain GeoJSON geometries with different types.
///
/// - Warning: Currently only the point GeoJSON geometry is supported
///
/// Encoded as:
///
///     {
///         "id"       : "0521fccf-3799-4786-aab1-e5e5108c0807",
///         "canvas"   : "e5db7eb2-bd9f-44ba-9c90-e6e6e528b930",
///         "annotationType" : "photoMarker",
///         "coordinates": [-96.77546339604037, 32.82483564429168]
///     }
struct FirebaseGeometry: Codable, FirebaseToRealmSyncable {
    typealias ModelType = Geometry

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case id
        case canvas
        case annotationType
        case coordinates
    }

    /// UUID identifier of parent canvas
    var canvasId: String
    /// decodes into Range Geometry
    var geometry: Geometry

    /// Constructor taking the geometry
    init(canvasId: String, geometry: Geometry) {
        self.canvasId = canvasId
        self.geometry = geometry
    }

    /// Custom implementation of decoding that handles different geometry types
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        canvasId = try container.decode(String.self, forKey: .canvas)
        let type = try container.decode(String.self, forKey: .annotationType)
        if type != Geometry.AnnotationType.photoMarker.rawValue {
            throw DecodingError.dataCorruptedError(
                forKey: .annotationType,
                in: container,
                debugDescription: "Unsupported annotationType: \(type)"
            )
        }
        var coordinatesContainer = try container.nestedUnkeyedContainer(forKey: .coordinates)
        let longitude = try coordinatesContainer.decode(Double.self)
        let latitude = try coordinatesContainer.decode(Double.self)
        let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        geometry = Geometry(id: id, annotationType: .photoMarker, geometry: .point(Point(coordinates)))
    }

    /// Custom implementation of encoding that handles different geometry types
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(geometry.id, forKey: .id)
        try container.encode(canvasId, forKey: .canvas)
        try container.encode(geometry.annotationType.rawValue, forKey: .annotationType)
        switch geometry.geometry {
        case let .point(point):
            var coordinatesContainer = container.nestedUnkeyedContainer(forKey: .coordinates)
            try coordinatesContainer.encode(point.coordinates.longitude)
            try coordinatesContainer.encode(point.coordinates.latitude)
        default:
            let context = EncodingError.Context(codingPath: encoder.codingPath,
                                                debugDescription: "Unsupported geometry")
            throw EncodingError.invalidValue(self, context)
        }
    }

    /// Add or update the geometry and add to canvas. Fails if canvas not found for geometry
    func upsert(_ realm: Realm) throws {
        guard let canvas = realm.object(ofType: PDFCanvas.self, forPrimaryKey: canvasId) else {
            throw "canvas not found: \(canvasId)"
        }
        realm.add(geometry, update: .modified)
        canvas.geometries.insert(geometry)
    }
}
