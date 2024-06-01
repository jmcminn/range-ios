import Foundation
import UIKit

/// Definition of a line annotation
class LineAnnotation: Annotation {
    /// position of the start point of the end
    var startPoint: CGPoint { didSet {
        startPoint = startPoint.roundCoordinates()
        postUpdate()
    }}
    /// position of the end point of the line
    var endPoint: CGPoint { didSet {
        endPoint = endPoint.roundCoordinates()
        postUpdate()
    }}
    /// line thickness
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
        super.init(id: id, type: .line)
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

    override func duplicate(withOffset offset: CGPoint) -> LineAnnotation {
        .init(
            startPoint: startPoint.addTo(offset),
            endPoint: endPoint.addTo(offset),
            lineWidth: lineWidth,
            color: color
        )
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? LineAnnotation else { return false }
        if id != rhs.id { return false }
        if startPoint != rhs.startPoint { return false }
        if endPoint != rhs.endPoint { return false }
        if lineWidth != rhs.lineWidth { return false }
        if hexColor != rhs.hexColor { return false }
        return true
    }

    /// Deep copy of the annotation
    override func copy(with _: NSZone? = nil) -> Any {
        LineAnnotation(
            id: id,
            startPoint: startPoint,
            endPoint: endPoint,
            lineWidth: lineWidth,
            color: color
        )
    }
}
