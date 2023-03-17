import CoreLocation
import Foundation
import OSLog
import PDFKit
import RealmSwift

/// Structures and enums required to represent CanvasSources with different types

/// Supported canvas source types, all others are ignored by Range iOS app
enum CanvasSourceType: String, Codable, PersistableEnum {
    case pdf, mapbox, droneDeploy = "dronedeploy"
    init?(fromString: String) {
        if let type = CanvasSourceType.allCases.first(where: { $0.rawValue == fromString }) {
            self = type
        } else { return nil }
    }
}

/// Defines alternative representations of CanvasSource as enum
enum CanvasSourceData: Equatable {
    case pdf(_ data: PdfCanvasSourceData)
    case mapbox(_ data: MapboxCanvasSourceData)
    case droneDeploy(_ data: DroneDeployCanvasSourceData)

    /// Get the type for this canvas source data
    var type: CanvasSourceType {
        switch self {
        case let .pdf(data):
            return data.type
        case let .mapbox(data):
            return data.type
        case let .droneDeploy(data):
            return data.type
        }
    }

    var canvasNamePrefix: String? {
        switch self {
        case let .pdf(data): return data.sheetNumber
        default: return nil
        }
    }
}

/// PDF Canvas Source definition
struct PdfCanvasSourceData: Equatable, Codable {
    /// The type needs to be stored so it's encoded into db (so later it can be used to decode the proper representation)
    var type: CanvasSourceType = .pdf
    /// sheet identifier
    var sheetNumber: String?
    /// 0-based PDF page number
    var pageNumber: Int
    /// the scale of PDF. Example value: 48.0, meaning the scale is 1:48
    var userDefinedScale: Double

    init(sheetNumber: String? = nil, pageNumber: Int, userDefinedScale: Double) {
        self.sheetNumber = sheetNumber
        self.pageNumber = pageNumber
        self.userDefinedScale = userDefinedScale
    }
}

/// Mapbox Canvas Source definition
struct MapboxCanvasSourceData: Equatable, Codable {
    var type: CanvasSourceType = .mapbox
    /// mapbox zoom for map canvas
    var zoom: Double
    var center: LocationCoordinate2DCodable
    var styleUrl: String

    init(zoom: Double, center: LocationCoordinate2DCodable, styleUrl: String) {
        self.zoom = zoom
        self.center = center
        self.styleUrl = styleUrl
    }
}

/// DroneDeploy Canvas Source definition
struct DroneDeployCanvasSourceData: Equatable, Codable {
    var type: CanvasSourceType = .droneDeploy
    var zoom: Double
    var center: LocationCoordinate2DCodable
    var styleUrl: String
    var tilesetUrl: String

    init(zoom: Double, center: LocationCoordinate2DCodable, styleUrl: String, tilesetUrl: String) {
        self.zoom = zoom
        self.center = center
        self.styleUrl = styleUrl
        self.tilesetUrl = tilesetUrl
    }
}

/// Custom Codable so it's encoded as { type: , ... } and not the default encoding for swift enums which adds 2 levels of hierarchy in the json
extension CanvasSourceData: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let typeContainer = try decoder.container(keyedBy: CodingKeys.self)
        let container = try decoder.singleValueContainer()
        switch try typeContainer.decode(CanvasSourceType.self, forKey: .type) {
        case .pdf:
            self = .pdf(try container.decode(PdfCanvasSourceData.self))
        case .mapbox:
            self = .mapbox(try container.decode(MapboxCanvasSourceData.self))
        case .droneDeploy:
            self = .droneDeploy(try container.decode(DroneDeployCanvasSourceData.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .pdf(data):
            try container.encode(data)
        case let .mapbox(data):
            try container.encode(data)
        case let .droneDeploy(data):
            try container.encode(data)
        }
    }
}

/// Store CanvasSourceData in the Realm as a JSON string
extension CanvasSourceData: FailableCustomPersistable {
    // The type persisted to the database
    public typealias PersistedType = String
    // Construct an instance of the mapped type from the persisted type.
    // When reading from the database, this converts the persisted type to the mapped type.
    public init?(persistedValue: PersistedType) {
        if let data = persistedValue.data(using: .utf8) {
            do {
                let decoded = try JSONDecoder().decode(CanvasSourceData.self, from: data)
                self = decoded
                return
            } catch {
                Logger.model.error("decoding CanvasSourceData failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        return nil
    }

    // Construct an instance of the persisted type from the mapped type.
    // When writing to the database, this converts the mapped type to a persistable type.
    public var persistableValue: PersistedType {
        do {
            let encoded = try JSONEncoder().encode(self)
            if let json = String(data: encoded, encoding: .utf8) {
                return json
            }
        } catch {
            Logger.model.error("encoding CanvasSourceData failed: \(error.localizedDescription, privacy: .public)")
        }
        return ""
    }
}
