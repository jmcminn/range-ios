import CoreLocation
import Foundation
import RealmSwift
import Turf

// TODO: 44 move somewhere and document
struct LocationCoordinate2DCodable: Codable {
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees
    var decodedCoordinates: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(longitude)
        try container.encode(latitude)
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        longitude = try container.decode(CLLocationDegrees.self)
        latitude = try container.decode(CLLocationDegrees.self)
    }

    init(_ coordinates: CLLocationCoordinate2D) {
        latitude = coordinates.latitude
        longitude = coordinates.longitude
    }
}

class CreatePhotoMarkerCommand: Command, Equatable, Codable {
    let canvasId: String
    let geometryId: String
    let featureId: String
    let collaborationId: String
    private let coordinatesCodable: LocationCoordinate2DCodable
    lazy var coordinates: CLLocationCoordinate2D = coordinatesCodable.decodedCoordinates
    /// CodingKeys used by Codable as a keys in the encoded form
    private enum CodingKeys: String, CodingKey {
        case canvasId, geometryId, featureId, collaborationId, coordinatesCodable = "coordinates"
    }

    init(
        canvasId: String,
        geometryId: String,
        featureId: String,
        collaborationId: String,
        coordinates: CLLocationCoordinate2D
    ) {
        self.canvasId = canvasId
        self.geometryId = geometryId
        self.featureId = featureId
        self.collaborationId = collaborationId
        coordinatesCodable = .init(coordinates)
    }

    static func == (lhs: CreatePhotoMarkerCommand, rhs: CreatePhotoMarkerCommand) -> Bool {
        lhs.collaborationId == rhs.collaborationId
    }
}

extension CreatePhotoMarkerCommand: LocalCommand {
    func applyLocally(writer: ProjectModelWriter) async throws {
        // resolve the canvas in the write realm
        try await writer.write { realm in
            guard let canvas = realm.object(ofType: PDFCanvas.self, forPrimaryKey: self.canvasId) else {
                // this shouldn't really happen as the canvas cannot be removed...
                throw ModelError.canvasNotFound
            }
            let geometry = Geometry(
                id: self.geometryId,
                annotationType: .photoMarker,
                geometry: .point(Point(self.coordinates))
            )
            let feature = Feature(id: self.featureId, name: "")
            let collaboration = Collaboration(id: self.collaborationId, name: "", description: "")

            realm.add(geometry, update: .error)
            realm.add(feature, update: .error)
            realm.add(collaboration, update: .error)
            canvas.geometries.insert(geometry)
            geometry.features.insert(feature)
            feature.collaborations.insert(collaboration)
        }
    }
}
