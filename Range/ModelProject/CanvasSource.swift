import CoreLocation
import Foundation
import OSLog
import PDFKit
import RealmSwift

/// Supported canvas source types, all others are ignored by Range iOS app
enum CanvasSourceType: String, Codable, PersistableEnum {
    case pdf, mapbox, droneDeploy = "dronedeploy"
    init?(fromString: String) {
        if let type = CanvasSourceType.allCases.first(where: { $0.rawValue == fromString }) {
            self = type
        } else { return nil }
    }
}

// Realm object for `project/<id>/canvasSources/<id>`.
class CanvasSource: Object, WithPlaceholder, WithId {
    /// Primary key, UUID
    @Persisted(primaryKey: true) var id: String
    /// Backlink to the canvas. This is automatically updated whenever this canvas source is added to or removed from the parent
    @Persisted(originProperty: "canvasSources") var canvas: LinkingObjects<Canvas>
    /// The type
    @Persisted var type: CanvasSourceType = .pdf
    /// The name of canvas source
    @Persisted var name: String
    /// The center
    @Persisted var center: CLLocationCoordinate2D
    /// For pdf canvas sources comes from model, for other types it's always set to 0 (not present in the model)
    @Persisted var rotation: Double
    /// For pdf canvases comes from model. Otherwise it's assumed to be true (as we can assume mapbox and dronedeploy are geolocated)
    @Persisted var isGeolocated: Bool
    /// Only for 'pdf' type - the scale of PDF. Example value: 48.0, meaning the scale is 1:48
    @Persisted var userDefinedScale: Double?
    /// Only for 'pdf' type. version of the pdf file, to recognize when new pdf was uploaded
    @Persisted var mainStorageVersion: String?
    /// Only for mapbox/dronedeploy types - mapbox zoom for map canvas
    @Persisted var zoom: Double?
    /// Only for mapbox/dronedeploy types, mapbox style url
    @Persisted var styleUrl: String?
    /// Only for dronedeploy types, dronedeploy tileset url
    @Persisted var tilesetUrl: String?
    /// Whether this object is just a placeholder for a real object
    @Persisted var placeholder: Bool = false

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
    init(
        id: String,
        type: CanvasSourceType,
        name: String,
        center: CLLocationCoordinate2D,
        rotation: Double,
        isGeolocated: Bool,
        userDefinedScale: Double?,
        mainStorageVersion: String?,
        zoom: Double?,
        styleUrl: String?,
        tilesetUrl: String?,
        placeholder: Bool = false
    ) {
        super.init()
        self.id = id
        self.type = type
        self.name = name
        self.center = center
        self.rotation = rotation
        self.isGeolocated = isGeolocated
        self.userDefinedScale = userDefinedScale
        self.mainStorageVersion = mainStorageVersion
        self.zoom = zoom
        self.styleUrl = styleUrl
        self.tilesetUrl = tilesetUrl
        self.placeholder = placeholder
    }

    /// Convenience initializer for placeholder object
    required convenience init(placeholderId id: String) {
        self.init(
            id: id,
            type: .pdf,
            name: "",
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            rotation: 0,
            isGeolocated: false,
            userDefinedScale: 1,
            mainStorageVersion: nil,
            zoom: nil,
            styleUrl: nil,
            tilesetUrl: nil,
            placeholder: true
        )
    }
}
