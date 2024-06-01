import Foundation
import UIKit

/// Definition of an arrow annotation
class ArrowAnnotation: Annotation {
    /// position of the start point of the arrow (the one with no arrow tip)
    var startPoint: CGPoint { didSet {
        startPoint = startPoint.roundCoordinates()
        postUpdate()
    }}
    /// position of the end point of the arrow (the one with arrow tip)
    var endPoint: CGPoint { didSet {
        endPoint = endPoint.roundCoordinates()
        postUpdate()
    }}
    /// arrow thickness
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

    /// The length of a single arrow tip line (the angle between tip line and arrow line is 45deg)
    /// Arrow tip length depends on the line width
    /// This is scaled value
    var tipLength: Double { 4 * lineWidth }

    private enum CodingKeys: String, CodingKey {
        case startPoint, endPoint, lineWidth, hexColor
    }

    init(
        id: String = UUID().uuidString.lowercased(),
        startPoint: CGPoint,
        endPoint: CGPoint,
        lineWidth: Double,
        color: UIColor
    ) {
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.lineWidth = lineWidth
        self.color = color
        hexColor = color.hexString
        super.init(id: id, type: .arrow)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startPoint = try container.decode(CGPoint.self, forKey: .startPoint)
        endPoint = try container.decode(CGPoint.self, forKey: .endPoint)
        lineWidth = try container.decode(Double.self, forKey: .lineWidth)
        hexColor = try container.decode(String.self, forKey: .hexColor)
        color = UIColor(hexString: hexColor) ?? .black
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startPoint._rounded(toPlaces: 2), forKey: .startPoint)
        try container.encode(endPoint._rounded(toPlaces: 2), forKey: .endPoint)
        try container.encode(lineWidth._rounded(toPlaces: 6), forKey: .lineWidth)
        try container.encode(hexColor, forKey: .hexColor)
        try super.encode(to: encoder)
    }

    override func duplicate(withOffset offset: CGPoint) -> ArrowAnnotation {
        .init(
            startPoint: startPoint.addTo(offset),
            endPoint: endPoint.addTo(offset),
            lineWidth: lineWidth,
            color: color
        )
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? ArrowAnnotation else { return false }
        if id != rhs.id { return false }
        if startPoint != rhs.startPoint { return false }
        if endPoint != rhs.endPoint { return false }
        if lineWidth != rhs.lineWidth { return false }
        if hexColor != rhs.hexColor { return false }
        return true
    }

    /// Deep copy of the annotation
    override func copy(with _: NSZone? = nil) -> Any {
        ArrowAnnotation(
            id: id,
            startPoint: startPoint,
            endPoint: endPoint,
            lineWidth: lineWidth,
            color: color
        )
    }
}
