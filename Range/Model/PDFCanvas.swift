import CoreLocation
import Foundation
import PDFKit
import RealmSwift

/// Realm object for `project/details/canvases/<id>`.
class PDFCanvas: Object {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// URL of the PDF
    @Persisted var url: String
    /// 0-based PDF page number
    @Persisted var pageNumber: Int
    /// the scale of PDF. Example value: 48.0, meaning the scale is 1:48
    @Persisted var userDefinedScale: Double
    /// geometries for this canvas, the order doesn't matter so it's a set
    @Persisted var geometries: MutableSet<Geometry>

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(id: String, url: String, pageNumber: Int, userDefinedScale: Double) {
        super.init()
        self.id = id
        self.url = url
        self.pageNumber = pageNumber
        self.userDefinedScale = userDefinedScale
    }
}
