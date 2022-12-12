import CoreLocation
import Foundation
import PDFKit
import RealmSwift

/// Realm object for `project/details/canvases/<id>`.
class PDFCanvas: Object, WithPlaceholder {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String

    /// Backlink to the collection. This is automatically updated whenever this canvas is added to or removed from the parent
    @Persisted(originProperty: "canvases") var collection: LinkingObjects<CanvasCollection>
    /// The name of canvas
    @Persisted var name: String
    /// 0-based PDF page number
    @Persisted var pageNumber: Int
    /// The sheet number
    @Persisted var sheetNumber: String?
    /// the scale of PDF. Example value: 48.0, meaning the scale is 1:48
    @Persisted var userDefinedScale: Double
    /// geometries for this canvas, the order doesn't matter so it's a set
    @Persisted var geometries: MutableSet<Geometry>
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// The value to display in the UI
    var displayName: String {
        var components: [String] = []
        if let sheetNumber = sheetNumber, !sheetNumber.isEmpty { components.append(sheetNumber) }
        if !name.isEmpty { components.append(name) }
        return components.joined(separator: " • ")
    }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(
        id: String,
        name: String,
        pageNumber: Int,
        sheetNumber: String?,
        userDefinedScale: Double,
        placeholder: Bool = false
    ) {
        super.init()
        self.id = id
        self.name = name
        self.pageNumber = pageNumber
        self.sheetNumber = sheetNumber
        self.userDefinedScale = userDefinedScale
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(
            id: id,
            name: "",
            pageNumber: 0,
            sheetNumber: nil,
            userDefinedScale: 0,
            placeholder: true
        )
    }
}
