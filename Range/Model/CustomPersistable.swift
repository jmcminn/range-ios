import CoreLocation
import Foundation
import OSLog
import RealmSwift
import Turf
import UIKit

/// Support for custom types not supported natively by Realm Swift SDK
/// https://www.mongodb.com/docs/realm/sdk/swift/data-types/type-projection/

/// Since Realm has no native support for storing LocationCoordinate(s) we need to define an EmbeddedObject for Location and add custom persistence for CLLocationCoordinate2D
public class Location: EmbeddedObject {
    @Persisted var latitude: Double
    @Persisted var longitude: Double
}

// Extend a type as a CustomPersistable if if is impossible for
// conversion between the mapped type and the persisted type to fail.
extension CLLocationCoordinate2D: CustomPersistable {
    // Define the storage object that is persisted to the database.
    // The `PersistedType` must be a type that Realm supports.
    // In this example, the PersistedType is an embedded object.
    public typealias PersistedType = Location
    // Construct an instance of the mapped type from the persisted type.
    // When reading from the database, this converts the persisted type to the mapped type.
    public init(persistedValue: PersistedType) {
        self.init(latitude: persistedValue.latitude, longitude: persistedValue.longitude)
    }

    // Construct an instance of the persisted type from the mapped type.
    // When writing to the database, this converts the mapped type to a persistable type.
    public var persistableValue: PersistedType {
        Location(value: [latitude, longitude])
    }
}

// TODO: 44 move somewhere and document
struct LocationCoordinate2DCodable: Codable {
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees
    var decodedCoordinates: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(longitude)
        try container.encode(latitude)
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        longitude = try container.decode(CLLocationDegrees.self)
        latitude = try container.decode(CLLocationDegrees.self)
    }

    init(_ coordinates: CLLocationCoordinate2D) {
        latitude = coordinates.latitude
        longitude = coordinates.longitude
    }
}

/// Store Turf.Geometry in the Realm as a JSON string
extension Turf.Geometry: FailableCustomPersistable {
    // Define the storage object that is persisted to the database.
    // The `PersistedType` must be a type that Realm supports.
    // In this example, the PersistedType is an embedded object.
    public typealias PersistedType = String
    // Construct an instance of the mapped type from the persisted type.
    // When reading from the database, this converts the persisted type to the mapped type.
    public init?(persistedValue: PersistedType) {
        if let data = persistedValue.data(using: .utf8) {
            do {
                let decoded = try JSONDecoder().decode(Turf.Geometry.self, from: data)
                self = decoded
                return
            } catch {
                Logger.model.error("decoding geometry failed: \(error.localizedDescription, privacy: .public)")
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
            Logger.model.error("encoding geometry failed: \(error.localizedDescription, privacy: .public)")
        }
        return ""
    }
}

/// Store URL as String, it's failable as initiating URL with String returns nil for not well formed urls
extension URL: FailableCustomPersistable {
    public typealias PersistedType = String
    // Construct URL from String
    public init?(persistedValue: String) { self.init(string: persistedValue) }
    // Get String to store in the database
    public var persistableValue: String { absoluteString }
}

// TODO: 44 here
/// Store ActionCommand in the Realm as a JSON string
// extension ActionCommand: FailableCustomPersistable {
//    // Define the storage object that is persisted to the database.
//    // The `PersistedType` must be a type that Realm supports.
//    // In this example, the PersistedType is an embedded object.
//    public typealias PersistedType = String
//    // Construct an instance of the mapped type from the persisted type.
//    // When reading from the database, this converts the persisted type to the mapped type.
//    public init?(persistedValue: PersistedType) {
//        if let data = persistedValue.data(using: .utf8) {
//            do {
//                let decoded = try JSONDecoder().decode(ActionCommand.self, from: data)
//                self = decoded
//                return
//            } catch {
//                Logger.model.error("decoding action command failed: \(error.localizedDescription, privacy: .public)")
//            }
//        }
//        return nil
//    }
//
//    // Construct an instance of the persisted type from the mapped type.
//    // When writing to the database, this converts the mapped type to a persistable type.
//    public var persistableValue: PersistedType {
//        do {
//            let encoded = try JSONEncoder().encode(self)
//            if let json = String(data: encoded, encoding: .utf8) {
//                return json
//            }
//        } catch {
//            Logger.model.error("encoding action command failed: \(error.localizedDescription, privacy: .public)")
//        }
//        return ""
//    }
// }
