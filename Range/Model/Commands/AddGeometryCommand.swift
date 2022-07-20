import Foundation
import RealmSwift
import Turf

struct AddGeometryCommand: Command {
    let geometryId: String
    let canvasId: String
    let annotationType: Geometry.AnnotationType
    let geometry: Turf.Geometry

    func applyLocally(inRealm realm: Realm) throws {
        let canvas = realm.objectOrPlaceholder(ofType: PDFCanvas.self, forPrimaryKey: canvasId)
        let geometry = Geometry(id: geometryId, annotationType: annotationType, geometry: geometry)
        realm.add(geometry, update: .modified)
        canvas.geometries.insert(geometry)
    }
}
