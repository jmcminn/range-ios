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

    /// UUID of the geometry
    var id: String
    /// UUID identifier of parent canvas
    var canvasId: String
    /// the only supported annotation type is photo marker
    var annotationType: Geometry.AnnotationType = .photoMarker
    /// decodes into Turf Geometry
    var geometry: Turf.Geometry = .point(Point(CLLocationCoordinate2D(latitude: 0, longitude: 0)))

    /// Initializer to init all the fields of object.
    init(id: String, canvasId: String, geometry: Turf.Geometry) {
        self.id = id
        self.canvasId = canvasId
        self.geometry = geometry
    }

    /// Custom implementation of decoding that handles different geometry types
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        canvasId = try container.decode(String.self, forKey: .canvas)
        let type = try container.decode(String.self, forKey: .annotationType)
        if type != annotationType.rawValue {
            throw DecodingError.dataCorruptedError(
                forKey: .annotationType,
                in: container,
                debugDescription: "Unsupported annotationType: \(type)"
            )
        }
        // TODO: 44 firebase
//        var coordinatesContainer = try container.nestedUnkeyedContainer(forKey: .coordinates)
//        let longitude = try coordinatesContainer.decode(Double.self)
//        let latitude = try coordinatesContainer.decode(Double.self)
//        let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        // TODO: 44 vs firestore
        let coordinatesString = try container.decode(String.self, forKey: .coordinates)
        let coordinatesData = try coordinatesString.data(using: .utf8).or(error: DecodingError.dataCorruptedError(
            forKey: .annotationType,
            in: container,
            debugDescription: "Unsupported coordinates: \(coordinatesString)"
        ))
        let coordinatesArray = try JSONDecoder().decode([Double].self, from: coordinatesData)
        let coordinates = CLLocationCoordinate2D(latitude: coordinatesArray[1], longitude: coordinatesArray[0])

        geometry = .point(Point(coordinates))
    }

    /// Custom implementation of encoding that handles different geometry types
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(canvasId, forKey: .canvas)
        try container.encode(annotationType.rawValue, forKey: .annotationType)
        switch geometry {
        case let .point(point):
            // TODO: 44 firebase
//            var coordinatesContainer = container.nestedUnkeyedContainer(forKey: .coordinates)
//            try coordinatesContainer.encode(point.coordinates.longitude)
//            try coordinatesContainer.encode(point.coordinates.latitude)
            // TODO: 44 vs firestore
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
    }

    /// Add or update the geometry and add to canvas. Fails if canvas not found for geometry
    func upsert(_ realm: Realm) throws {
        guard let canvas = realm.object(ofType: PDFCanvas.self, forPrimaryKey: canvasId) else {
            throw "canvas not found: \(canvasId)"
        }
        let geometry = Geometry(id: id, annotationType: annotationType, geometry: geometry)
        realm.add(geometry, update: .modified)
        canvas.geometries.insert(geometry)
    }
}
