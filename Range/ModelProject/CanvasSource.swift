import CoreLocation
import Foundation
import OSLog
import PDFKit
import RealmSwift

// Realm object for `project/<id>/canvasSources/<id>`.
class CanvasSource: Object, WithPlaceholder, WithId {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// Backlink to the canvas. This is automatically updated whenever this canvas source is added to or removed from the parent
    @Persisted(originProperty: "canvasSources") var canvas: LinkingObjects<Canvas>
    /// The name of canvas source
    @Persisted var name: String
    /// Canvas source type dependent data (Realm requires some default value)
    @Persisted var data: CanvasSourceData = .pdf(PdfCanvasSourceData(pageNumber: 0, userDefinedScale: 1))
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

    /// CanvasSource type, based on the CanvasSourceData.type
    var type: CanvasSourceType { data.type }

    /// Added to canvas name when there's only one canvas source for canvas
    /// Hack to get pdf.sheetNumber displayed in the canvas selector
    var canvasNamePrefix: String? { data.canvasNamePrefix }

    // order: mapbox, dronedeploy, pdf
    // Otherwise sort by id asc
    static var sortingOrder: (CanvasSource, CanvasSource) -> Bool = { cs1, cs2 -> Bool in
        if cs1.type == cs2.type {
            return cs1.id < cs2.id
        }
        switch cs1.type {
        case .mapbox: return true // first
        case .droneDeploy: return cs2.type == .pdf // dronedeploy before pdf
        case .pdf: return false // last
        }
    }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields
    init(id: String, name: String, data: CanvasSourceData, placeholder: Bool = false) {
        super.init()
        self.id = id
        self.name = name
        self.data = data
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(
            id: id,
            name: "",
            data: .pdf(PdfCanvasSourceData(pageNumber: 0, userDefinedScale: 1)),
            placeholder: true
        )
    }
}
