import Foundation
import OSLog
import RealmSwift
import UIKit

/// The root object for annotations
final class Annotations: NSObject, Codable {
    /// Specifies the format and version of the annotations
    private(set) var format: String = "https://range.io/photo-annotations/v1"

    /// Annotations and image width and height
    private(set) var width: Int
    private(set) var height: Int

    /// Scale applied to annotation sizes (like thickness from Annotations+Dictionaries). For example if scale is 2 then scribble annotation
    /// added with ".medium" thickness will have a lineWidth of 2 * medium.lineWidth = 2 * 6 = 12 pixels (when rendered on the photo)
    private(set) var scale: Double
    var annotations: [Annotation]

    init(width: Int, height: Int, scale: Double, _ annotations: [Annotation]) {
        self.width = width
        self.height = height
        self.scale = scale
        self.annotations = annotations
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? Annotations else { return false }
        if format != rhs.format { return false }
        if width != rhs.width { return false }
        if height != rhs.height { return false }
        if scale != rhs.scale { return false }
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
                self.init(width: decoded.width, height: decoded.height, scale: decoded.scale, decoded.annotations)
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
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let encoded = try encoder.encode(self)
            if let json = String(data: encoded, encoding: .utf8) {
                return json
            }
        } catch {
            Logger.model.error("encoding Annotations failed: \(error.localizedDescription, privacy: .public)")
        }
        return ""
    }
}
