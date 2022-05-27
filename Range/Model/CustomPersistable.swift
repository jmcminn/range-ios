import CoreLocation
import Foundation
import OSLog
import RealmSwift
import Turf

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
