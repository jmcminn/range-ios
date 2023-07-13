import Foundation

/// Defines annotation types supported by Range iOS app
enum AnnotationType: String, Codable {
    case scribble
}

/// Defines annotations representations as enum (so we can have Annotation "superclass" kind of approach)
enum Annotation: Equatable {
    case scribble(_ data: ScribbleAnnotation)
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
        case .scribble:
            self = .scribble(try container.decode(ScribbleAnnotation.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .scribble(data):
            try container.encode(data)
        }
    }
}
