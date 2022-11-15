import CoreLocation
import Foundation
import PDFKit
import RealmSwift

/// Realm object for `project/details/canvases/<id>`.
class PDFCanvas: Object, WithPlaceholder {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// 0-based PDF page number
    @Persisted var pageNumber: Int
    /// the scale of PDF. Example value: 48.0, meaning the scale is 1:48
    @Persisted var userDefinedScale: Double
    /// geometries for this canvas, the order doesn't matter so it's a set
    @Persisted var geometries: MutableSet<Geometry>
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, pageNumber: Int, userDefinedScale: Double, placeholder: Bool = false) {
        super.init()
        self.id = id
        self.pageNumber = pageNumber
        self.userDefinedScale = userDefinedScale
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(id: id, pageNumber: 0, userDefinedScale: 0, placeholder: true)
    }
}
