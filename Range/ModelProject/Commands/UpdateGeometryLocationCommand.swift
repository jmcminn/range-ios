import CoreLocation
import FirebaseFirestore
import Foundation
import RealmSwift
import Turf

/// Update location (point geometry coordinates and canvas) for geometry
struct UpdateGeometryLocationCommand: Command, Codable, Equatable {
    var operations: [CommandOperationType : [String]] {
        [.update: [collaborationId]]
    }

    let collaborationId: String
    var canvasId: String
    var coordinates: LocationCoordinate2DCodable // no CLLocationCoordinate2D as it needs to be codable
    var coordinatesForFirestore: String

    init(collaborationId: String, canvasId: String, coordinates: CLLocationCoordinate2D) throws {
        self.collaborationId = collaborationId
        self.canvasId = canvasId
        self.coordinates = .init(coordinates)
        let coordinatesArray: [Double] = [coordinates.longitude, coordinates.latitude]
        let coordinatesData: Data = try JSONEncoder().encode(coordinatesArray)
        // convert for firestore already here, so we fail fast
        coordinatesForFirestore = try String(data: coordinatesData, encoding: .utf8)
            .or(error: "Coordinates not supported")
    }
}

extension UpdateGeometryLocationCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let geometry = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId)?.geometry.first
        else {
            throw ModelError.geometryNotFound
        }

        if geometry.canvas.first?.id != canvasId {
            guard let canvas = realm.object(ofType: Canvas.self, forPrimaryKey: canvasId) else {
                throw ModelError.canvasNotFound
            }
            // switch canvas
            geometry.canvas.first?.geometries.remove(geometry)
            canvas.geometries.insert(geometry)
        }
        geometry.geometry = .point(Point(coordinates.decodedCoordinates))
    }
}

/// Provide data for firebase function call
extension UpdateGeometryLocationCommand: FirebaseFunctionCommand {
    var functionName: String { "updateCollaboration" }

    var functionData: [String: Any?]? {
        [
            "collaborationId": collaborationId,
            "canvasId": canvasId,
            "coordinates": coordinatesForFirestore,
        ]
    }
}
