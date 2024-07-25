import CoreLocation
import FirebaseFirestore
import FirebaseFirestoreSwift
import Foundation
import OSLog
import RealmSwift
import Turf

/// Represents the `Geometry` (`projects/geometries` path in Firestore)
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
struct FirestoreGeometry: Decodable, FirestoreToRealmSyncable {
    typealias ModelType = Geometry

    /// CodingKeys used by Codable as a keys in the encoded form
    enum CodingKeys: String, CodingKey, CaseIterable {
        case annotationType, archivedTimestamp, canvas, coordinates
    }

    /// UUID identifier of parent canvas
    var canvasId: String
    /// the only supported annotation type is photo marker
    var annotationType: Geometry.AnnotationType = .photoMarker
    /// decodes into Turf Geometry
    var geometry: Turf.Geometry = .point(Point(CLLocationCoordinate2D(latitude: 0, longitude: 0)))
    /// not nil if the geometry was archived
    var archivedTimestamp: Date?

    init(canvasId: String, geometry: Turf.Geometry, archivedTimestamp: Date? = nil) {
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
        // archivedTimestamp can be encoded as Firestore.Timestamp or Int milliseconds (when coming from getAllData)
        do {
            archivedTimestamp = (try container.decodeIfPresent(Timestamp.self, forKey: .archivedTimestamp))?.dateValue()
        } catch {
            if let archivedTimestampMillis = try container.decodeIfPresent(Int.self, forKey: .archivedTimestamp) {
                archivedTimestamp = Date(timeIntervalSince1970: TimeInterval(archivedTimestampMillis) / 1000.0)
            }
        }
    }

    func upsert(withId id: String, inRealm realm: RealmSwift.Realm) throws {
        if let existingGeometry = realm.object(ofType: Geometry.self, forPrimaryKey: id),
           let previousCanvas = existingGeometry.canvas.first,
           previousCanvas.id != canvasId
        {
            // the geometry has changed canvas, remove from the previous one
            previousCanvas.geometries.remove(existingGeometry)
        }

        let canvas = realm.objectOrPlaceholder(ofType: Canvas.self, forPrimaryKey: canvasId)
        let geometry = Geometry(
            id: id,
            annotationType: annotationType,
            geometry: geometry,
            archivedTimestamp: archivedTimestamp
        )
        realm.add(geometry, update: .modified)
        canvas.geometries.insert(geometry)
    }
}
