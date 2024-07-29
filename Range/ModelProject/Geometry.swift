import CoreLocation
import Foundation
import RealmSwift
import Turf

/// Realm object for `project/details/geometry/<id>`
class Geometry: Object, WithId, WithPlaceholder {
    /// Supported annotation types, all others are ignored by Range iOS app
    enum AnnotationType: String, Codable, PersistableEnum {
        case photoMarker
    }

    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// Backlink to the canvas. This is automatically updated whenever this geometry is added to or removed from a canvas
    @Persisted(originProperty: "geometries") var canvas: LinkingObjects<Canvas>
    /// annotation type
    @Persisted var annotationType: AnnotationType
    /// the geometry shape is stored as Turf.Geometry as this is what Mapbox uses for representing geometries in their SDK
    /// some default is needed otherwise it cannot be marked as required (or it will crash when querying geometries using realm filters)
    @Persisted var geometry: Turf.Geometry = .point(Point(CLLocationCoordinate2D(latitude: 0, longitude: 0)))
    /// collaboraitons for this geometry, the order doesn't matter so it's a set
    @Persisted var collaborations: MutableSet<Collaboration>
    /// for archived geometries
    @Persisted var archivedTimestamp: Date?
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// Count all uploads from all collaborations
    var uploadsCount: Int {
        collaborations.reduce(0) { count, collaboration in
            count + collaboration.uploads.count
        }
    }

    /// If any collaboration has uncompleted notes
    var hasUncompletedNotes: Bool {
        collaborations.contains { $0.hasUncompletedNotes }
    }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(
        id: String,
        annotationType: AnnotationType,
        geometry: Turf.Geometry,
        archivedTimestamp: Date? = nil,
        placeholder: Bool = false
    ) {
        super.init()
        self.id = id
        self.annotationType = annotationType
        self.geometry = geometry
        self.archivedTimestamp = archivedTimestamp
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
