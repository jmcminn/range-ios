import CoreLocation
import Foundation
import RealmSwift

/// Realm object for `project/details/canvases/<id>`.
class Canvas: Object, WithPlaceholder {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// canvas sources for this canvas, the order doesn't matter so it's a set
    @Persisted var canvasSources: MutableSet<CanvasSource>
    /// Backlink to the collection. This is automatically updated whenever this canvas is added to or removed from the parent
    @Persisted(originProperty: "canvases") var collection: LinkingObjects<CanvasCollection>
    /// The name of canvas
    @Persisted var name: String

    /// geometries for this canvas, the order doesn't matter so it's a set
    @Persisted var geometries: MutableSet<Geometry>
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// The current canvas source for the currentCanvas, @objc dynamic so it can be observed
    @objc dynamic var currentCanvasSource: CanvasSource! {
        didSet {
            UserDefaults.setLastOpenCanvasSourceId(currentCanvasSource.id, forCanvasId: id)
        }
    }

    /// The value to display in the UI
    var displayName: String {
        // TODO: 930 if there's only 1 source prepend it's name to canvas.name
        name
//        var components: [String] = []
//        if let sheetNumber = sheetNumber, !sheetNumber.isEmpty { components.append(sheetNumber) }
//        if !name.isEmpty { components.append(name) }
//        return components.joined(separator: " • ")
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
