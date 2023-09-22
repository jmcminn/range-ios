import CoreLocation
import Foundation
import RealmSwift

/// Realm object for `project/details/canvases/<id>`.
class Canvas: Object, WithPlaceholder, WithId {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// canvas sources for this canvas, the order doesn't matter so it's a set
    @Persisted var canvasSources: MutableSet<CanvasSource>
    /// The name of canvas
    @Persisted var name: String

    /// geometries for this canvas, the order doesn't matter so it's a set
    @Persisted var geometries: MutableSet<Geometry>
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// The current canvas source for the currentCanvas, @objc dynamic so it can be observed
    @objc dynamic var currentCanvasSource: CanvasSource! {
        didSet {
            guard currentCanvasSource != nil else { return }
            UserDefaults.setLastOpenCanvasSourceId(currentCanvasSource.id, forCanvasId: id)
        }
    }

    /// Return all pins to be displayed for this canvas (not filtered)
    var pins: Results<Geometry> {
        geometries.where { $0.placeholder == false &&
            $0.annotationType == .photoMarker &&
            // has at least 1 collaboration (have > 0 features that have > 0 collaborations)
            ($0.features.collaborations.count > 0).count > 0
        }
    }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields.
    init(id: String, name: String, placeholder: Bool = false) {
        super.init()
        self.id = id
        self.name = name
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(id: id, name: "", placeholder: true)
    }
}
