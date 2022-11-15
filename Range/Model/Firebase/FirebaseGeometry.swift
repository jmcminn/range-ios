import CoreLocation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Foundation
import RealmSwift
import Turf

/// Represents the `Geometry` (`projects/geometries` path in Firebase)
///
/// It may contain GeoJSON geometries with different types.
///
/// - Warning: Currently only the point GeoJSON geometry is supported
///
/// Encoded as:
///
///     {
///         "canvas"   : "e5db7eb2-bd9f-44ba-9c90-e6e6e528b930",
///         "annotationType" : "photoMarker",
///         "coordinates": "[-96.77546339604037, 32.82483564429168]"
///     }
struct FirebaseGeometry: Codable, FirestoreToRealmSyncable {
    typealias ModelType = Geometry

    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case canvas, annotationType, coordinates, archivedTimestamp
    }

    /// UUID identifier of parent canvas
    var canvasId: String
    /// the only supported annotation type is photo marker
    var annotationType: Geometry.AnnotationType = .photoMarker
    /// decodes into Turf Geometry
    var geometry: Turf.Geometry = .point(Point(CLLocationCoordinate2D(latitude: 0, longitude: 0)))
    /// not nil if the geometry was archived
    var archivedTimestamp: Timestamp?

    init(canvasId: String, geometry: Turf.Geometry, archivedTimestamp: Timestamp? = nil) {
        self.canvasId = canvasId
        self.geometry = geometry
        self.archivedTimestamp = archivedTimestamp
    }

    /// Custom implementation of decoding that handles different geometry types
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        canvasId = try container.decode(String.self, forKey: .canvas)
        let type = try container.decode(String.self, forKey: .annotationType)
        if type != annotationType.rawValue {
            throw DecodingError.dataCorruptedError(
                forKey: .annotationType,
                in: container,
                debugDescription: "Unsupported annotationType: \(type)"
            )
        }
        let coordinatesString = try container.decode(String.self, forKey: .coordinates)
        let coordinatesData = try coordinatesString.data(using: .utf8).or(error: DecodingError.dataCorruptedError(
            forKey: .annotationType,
            in: container,
            debugDescription: "Unsupported coordinates: \(coordinatesString)"
        ))
        let coordinatesArray = try JSONDecoder().decode([Double].self, from: coordinatesData)
        let coordinates = CLLocationCoordinate2D(latitude: coordinatesArray[1], longitude: coordinatesArray[0])

        geometry = .point(Point(coordinates))
        archivedTimestamp = try container.decodeIfPresent(Timestamp.self, forKey: .archivedTimestamp)
    }

    /// Custom implementation of encoding that handles different geometry types
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(canvasId, forKey: .canvas)
        try container.encode(annotationType.rawValue, forKey: .annotationType)
        switch geometry {
        case let .point(point):
            let coordinatesArray: [Double] = [point.coordinates.longitude, point.coordinates.latitude]
            let coordinatesData: Data = try JSONEncoder().encode(coordinatesArray)
            let coordinatesString = try String(data: coordinatesData, encoding: .utf8)
                .or(error: EncodingError.invalidValue(self, EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unsupported coordinates"
                )))
            try container.encode(coordinatesString, forKey: .coordinates)
        default:
            let context = EncodingError.Context(codingPath: encoder.codingPath,
                                                debugDescription: "Unsupported geometry")
            throw EncodingError.invalidValue(self, context)
        }
        try container.encodeIfPresent(archivedTimestamp, forKey: .archivedTimestamp)
    }

    func upsertCommand(id: String) throws -> LocalCommand {
        UpsertGeometryCommand(
            geometryId: id,
            canvasId: canvasId,
            annotationType: annotationType,
            geometry: geometry,
            archivedTimestamp: archivedTimestamp?.dateValue()
        )
    }
}
