import Foundation
import RealmSwift
import Turf

/// Add or update the `Geometry`.
struct AddGeometryCommand: Command, Equatable {
    let geometryId: String
    var canvasId: String
    var annotationType: Geometry.AnnotationType
    var geometry: Turf.Geometry
    var archivedTimestamp: TimeInterval?

    func apply(inRealm realm: Realm) throws {
        let canvas = realm.objectOrPlaceholder(ofType: PDFCanvas.self, forPrimaryKey: canvasId)
        let geometry = Geometry(
            id: geometryId,
            annotationType: annotationType,
            geometry: geometry,
            archivedTimestamp: archivedTimestamp
        )
        realm.add(geometry, update: .modified)
        canvas.geometries.insert(geometry)
    }
}
