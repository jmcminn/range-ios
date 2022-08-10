import CoreLocation
import Foundation
import RealmSwift
import Turf

/// Realm object for `project/details/geometry/<id>`
class Geometry: Object, WithPlaceholder {
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
    /// some default is needed otherwise it cannot be marked as required (or it will crash when querying geometries using realm filters)
    @Persisted var geometry: Turf.Geometry = .point(Point(CLLocationCoordinate2D(latitude: 0, longitude: 0)))
    /// features for this geometry, the order doesn't matter so it's a set
    @Persisted var features: MutableSet<Feature>
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// Count all uploads from all features
    var uploadsCount: Int {
        features.reduce(0) { count, feature in
            count + feature.uploadsCount
        }
    }

    /// If any feature has uncompleted comments
    var hasUncompletedComments: Bool {
        features.contains { $0.hasUncompletedComments }
    }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, annotationType: AnnotationType, geometry: Turf.Geometry, placeholder: Bool = false) {
        super.init()
        self.id = id
        self.annotationType = annotationType
        self.geometry = geometry
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(
            id: id,
            annotationType: .photoMarker,
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 0, longitude: 0))),
            placeholder: true
        )
    }
}
