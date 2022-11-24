import CoreLocation
import Foundation
import PDFKit
import RealmSwift

/// Realm object for `project/details/canvases/<id>`.
class PDFCanvas: Object, WithPlaceholder {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String

    /// The id for canvas collection. Canvas collection is not modelled in Realm as the only needed thing is the id (to fetch the PDF)
    @Persisted var canvasCollectionId: String
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

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(
        id: String,
        canvasCollectionId: String,
        name: String,
        pageNumber: Int,
        sheetNumber: String?,
        userDefinedScale: Double,
        placeholder: Bool = false
    ) {
        super.init()
        self.id = id
        self.canvasCollectionId = canvasCollectionId
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
            canvasCollectionId: "",
            name: "",
            pageNumber: 0,
            sheetNumber: nil,
            userDefinedScale: 0,
            placeholder: true
        )
    }
}
