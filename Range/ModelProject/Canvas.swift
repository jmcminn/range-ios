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

    // maps first (with any map source), followed by pdfs (with any pdf).
    // Sort pdfs by pageNumber asc.
    // Otherwise sort by id asc
    static var sortingOrder: (Canvas, Canvas) -> Bool = { (c1: Canvas, c2: Canvas) -> Bool in
        let c1HasPdfs = c1.canvasSources.contains { $0.type == .pdf }
        let c2HasPdfs = c2.canvasSources.contains { $0.type == .pdf }

        if c1HasPdfs, c2HasPdfs {
            guard let c1PdfSource = c1.canvasSources.first(where: { $0.type == .pdf }),
                  let c2PdfSource = c2.canvasSources.first(where: { $0.type == .pdf })
            else {
                // ignore source not found, this shouldn't happen
                return false
            }
            guard case let .pdf(data1) = c1PdfSource.data,
                  case let .pdf(data2) = c2PdfSource.data
            else {
                // ignore when there's no match, this shouldn't happen
                return false
            }
        }
        if !c1HasPdfs, !c2HasPdfs {
            return c1.id < c2.id
        }
        return !c1HasPdfs
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
