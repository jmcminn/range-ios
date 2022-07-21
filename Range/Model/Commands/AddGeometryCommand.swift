import Foundation
import RealmSwift
import Turf

struct AddGeometryCommand: Command, Equatable {
    let geometryId: String
    var canvasId: String
    var annotationType: Geometry.AnnotationType
    var geometry: Turf.Geometry

    func apply(inRealm realm: Realm) throws {
        let canvas = realm.objectOrPlaceholder(ofType: PDFCanvas.self, forPrimaryKey: canvasId)
        let geometry = Geometry(id: geometryId, annotationType: annotationType, geometry: geometry)
        realm.add(geometry, update: .modified)
        canvas.geometries.insert(geometry)
    }
}
