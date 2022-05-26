import CoreLocation
import Foundation
import RealmSwift
import Turf

/// Realm object for `project/details/geometry/<id>`
class Geometry: Object {
    /// Supported annotation types, all others are ignored by Range iOS app
    enum AnnotationType: String, PersistableEnum {
        case photoMarker
    }

    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// Backlink to the canvas. This is automatically updated whenever this geometry is added to or removed from a canvas
    @Persisted(originProperty: "geometries") var canvas: LinkingObjects<PDFCanvas>
    /// annotation type
    @Persisted var annotationType: AnnotationType
    /// the geometry shape is stored as Turf.Geometry as this is what Mapbox uses for representing geometries in their SDK
    @Persisted var geometry: Turf.Geometry
    /// features for this geometry, the order doesn't matter so it's a set
    @Persisted var features: MutableSet<Feature>

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, annotationType: AnnotationType, geometry: Turf.Geometry) {
        super.init()
        self.id = id
        self.annotationType = annotationType
        self.geometry = geometry
    }
}
