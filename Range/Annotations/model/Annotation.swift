import Foundation

/// Defines annotation types supported by Range iOS app
enum AnnotationType: String, Codable {
    case scribble, text, arrow
}

/// Defines annotations representations as enum (so we can have Annotation "superclass" kind of approach)
enum Annotation: Equatable, Hashable {
    case arrow(_ data: ArrowAnnotation)
    case scribble(_ data: ScribbleAnnotation)
    case text(_ data: TextAnnotation)

    func hash(into hasher: inout Hasher) {
        switch self {
        case let .arrow(data): hasher.combine(data.id)
        case let .scribble(data): hasher.combine(data.id)
        case let .text(data): hasher.combine(data.id)
        }
    }
}

/// A type that can be represented as a `Annotation` instance.
protocol AnnotationConvertible {
    /// The instance wrapped in a `Annotation` instance.
    var annotation: Annotation { get }
}

/// Custom Codable so it's encoded as { type: , ... } and not the default encoding for swift enums which adds 2 levels of hierarchy in the json
extension Annotation: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let typeContainer = try decoder.container(keyedBy: CodingKeys.self)
        let container = try decoder.singleValueContainer()
        switch try typeContainer.decode(AnnotationType.self, forKey: .type) {
        case .arrow: self = .arrow(try container.decode(ArrowAnnotation.self))
        case .scribble: self = .scribble(try container.decode(ScribbleAnnotation.self))
        case .text: self = .text(try container.decode(TextAnnotation.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .arrow(data): try container.encode(data)
        case let .scribble(data): try container.encode(data)
        case let .text(data): try container.encode(data)
        }
    }
}
