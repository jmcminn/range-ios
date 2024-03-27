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
    /// Calculated as: min(imageWidth, imageHeight) / Annotations.referenceViewSize
    private(set) var scale: Double

    var annotations: [Annotation]

    private enum CodingKeys: String, CodingKey {
        case format, width, height, scale, annotations
    }

    // to decide which annotation to decode Annotations need to partially decode it to get the
    // type and then use the proper class to decode the annotation data
    private enum AnnotationCodingKeys: String, CodingKey {
        case type
    }

    init(width: Int, height: Int, scale: Double, _ annotations: [Annotation]) {
        self.width = width
        self.height = height
        self.scale = scale
        self.annotations = annotations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        format = try container.decode(String.self, forKey: .format)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        scale = try container.decode(Double.self, forKey: .scale)

        // decode annotations. We need to select the proper Annotation subclass based on the type:
        annotations = []

        // as we have only 1 decode call per annotations array decoding, we need to do 2 passes
        // The first pass stores the annotation types
        var annotationTypes: [AnnotationType] = []
        var annotationsTypesContainer = try container.nestedUnkeyedContainer(forKey: .annotations)
        while !annotationsTypesContainer.isAtEnd {
            let annotationTypeContainer = try annotationsTypesContainer
                .nestedContainer(keyedBy: AnnotationCodingKeys.self)
            annotationTypes.append(try annotationTypeContainer.decode(AnnotationType.self, forKey: .type))
        }
        // The 2nd pass uses the annotation types from the first pass to decode given Annotation subclass
        var annotationsContainer = try container.nestedUnkeyedContainer(forKey: .annotations)
        while !annotationsContainer.isAtEnd {
            let annotation = switch annotationTypes[annotationsContainer.currentIndex] {
            case .scribble: try annotationsContainer.decode(ScribbleAnnotation.self)
            case .text: try annotationsContainer.decode(TextAnnotation.self)
            case .arrow: try annotationsContainer.decode(ArrowAnnotation.self)
            }
            annotations.append(annotation)
        }
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
