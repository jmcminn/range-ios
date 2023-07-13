import Foundation
import OSLog
import RealmSwift
import UIKit

/// The root object for annotations
final class Annotations: NSObject, Codable {
    private(set) var format: String = "https://range.io/photo-annotations/v1"

    var annotations: [Annotation]
    // TODO: 1270 store width/height/scale

    init(_ annotations: [Annotation]) {
        self.annotations = annotations
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? Annotations else { return false }
        if format != rhs.format { return false }
        if annotations != rhs.annotations { return false }
        return true
    }
}

/// Store Annotations in the Realm as a JSON string
extension Annotations: FailableCustomPersistable {
    // The type persisted to the database
    typealias PersistedType = String
    // Construct an instance of the mapped type from the persisted type.
    // When reading from the database, this converts the persisted type to the mapped type.
    convenience init?(persistedValue: PersistedType) {
        if let data = persistedValue.data(using: .utf8) {
            do {
                let decoded = try JSONDecoder().decode(Annotations.self, from: data)
                self.init(decoded.annotations)
                return
            } catch {
                Logger.model.error("decoding Annotations failed: \(error.localizedDescription, privacy: .public)")
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
            Logger.model.error("encoding Annotations failed: \(error.localizedDescription, privacy: .public)")
        }
        return ""
    }
}
