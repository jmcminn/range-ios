import Foundation
import UIKit

/// Definition of a scribble drawing
class ScribbleAnnotation: Annotation {
    /// Path in the image coordinates space
    var path: RangeBezierPath { didSet { postUpdate() }}
    /// scribble thickness
    var lineWidth: Double { didSet { postUpdate() }}
    /// the storage for color, String so it can be encoded/decoded
    private var hexColor: String
    /// inner color (the outline is always white) - UIColor wrapping the hexColor
    @Published var color: UIColor {
        didSet {
            hexColor = color.hexString
            postUpdate()
        }
    }

    private enum CodingKeys: String, CodingKey {
        case path, lineWidth, hexColor
    }

    init(
        id: String = UUID().uuidString.lowercased(),
        path: RangeBezierPath,
        lineWidth: Double,
        color: UIColor
    ) {
        self.path = path
        self.lineWidth = lineWidth
        self.color = color
        hexColor = color.hexString
        super.init(id: id, type: .scribble)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decode(RangeBezierPath.self, forKey: .path)
        lineWidth = try container.decode(Double.self, forKey: .lineWidth)
        hexColor = try container.decode(String.self, forKey: .hexColor)
        color = UIColor(hexString: hexColor) ?? .black
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(path, forKey: .path)
        try container.encode(lineWidth, forKey: .lineWidth)
        try container.encode(hexColor, forKey: .hexColor)
        try super.encode(to: encoder)
    }

    override func duplicate(withOffset offset: CGPoint) -> ScribbleAnnotation {
        .init(path: path.getTranslatedPath(x: offset.x, y: offset.y), lineWidth: lineWidth, color: color)
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? ScribbleAnnotation else { return false }
        if id != rhs.id { return false }
        if path != rhs.path { return false }
        if lineWidth != rhs.lineWidth { return false }
        if hexColor != rhs.hexColor { return false }
        return true
    }

    /// Deep copy of the annotation
    override func copy(with _: NSZone? = nil) -> Any {
        ScribbleAnnotation(id: id, path: path.copy() as! RangeBezierPath, lineWidth: lineWidth, color: color)
    }
}
