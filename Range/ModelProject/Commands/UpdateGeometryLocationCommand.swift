import CoreLocation
import FirebaseFirestore
import Foundation
import RealmSwift
import Turf

/// Update location (point geometry coordinates and canvas) for geometry
struct UpdateGeometryLocationCommand: Command, Codable, Equatable {
    let geometryId: String
    var canvasId: String
    var coordinates: LocationCoordinate2DCodable // no CLLocationCoordinate2D as it needs to be codable
    var coordinatesForFirestore: String

    init(geometryId: String, canvasId: String, coordinates: CLLocationCoordinate2D) throws {
        self.geometryId = geometryId
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
        guard let geometry = realm.object(ofType: Geometry.self, forPrimaryKey: geometryId) else {
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

/// Apply the `Comment` update in Firestore.
extension UpdateGeometryLocationCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise abort (the command cannot be applied)
        guard try ctx.exists(.geometry(geometryId)) else {
            throw FirestoreCommandError.obsolete("geometry doesn't exist")
        }
        guard try ctx.exists(.canvas(canvasId)) else {
            throw FirestoreCommandError.obsolete("canvas doesn't exist")
        }

        // ------------- WRITES ----------------
        ctx.updateData(
            [
                FirestoreGeometry.CodingKeys.canvas.rawValue: canvasId,
                FirestoreGeometry.CodingKeys.coordinates.rawValue: coordinatesForFirestore,
            ],
            forDocument: .geometry(geometryId)
        )
    }
}
