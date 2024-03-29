import Foundation
import UIKit

/// Definition of a text box annotation
class TextAnnotation: Annotation {
    /// text
    var text: String { didSet { postUpdate() }}
    /// position of the top left corner of the text box (including the white background)
    var position: CGPoint { didSet {
        position = position.roundCoordinates()
        postUpdate()
    }}
    /// font size in in pixels (this value is stored when saving the annotation)
    var fontSize: Double { didSet { postUpdate() }}
    /// One of the FontSize values if fontSize matches any of them.
    /// Requires annotationsScale to be calculated as it's an unscaled value and fontSize is scaled
    func fontSizeEnum(_ annotationScale: Double) -> Annotations.FontSize? {
        let unscaledFontSize = fontSize / annotationScale
        return Annotations.FontSize.allCases.first { $0.size == unscaledFontSize }
    }

    /// the storage for color, String so it can be encoded/decoded
    private(set) var hexColor: String
    /// inner color (the outline is always white) - UIColor wrapping the hexColor
    @Published var color: UIColor {
        didSet {
            hexColor = color.hexString
            postUpdate()
        }
    }

    private enum CodingKeys: String, CodingKey {
        case text, position, fontSize, hexColor
    }

    init(
        id: String = UUID().uuidString.lowercased(),
        text: String,
        position: CGPoint,
        fontSize: Double,
        color: UIColor
    ) {
        self.text = text
        self.position = position.roundCoordinates()
        self.fontSize = fontSize
        self.color = color
        hexColor = color.hexString
        super.init(id: id, type: .text)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        position = try container.decode(CGPoint.self, forKey: .position)
        fontSize = try container.decode(Double.self, forKey: .fontSize)
        hexColor = try container.decode(String.self, forKey: .hexColor)
        color = UIColor(hexString: hexColor) ?? .black
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(position, forKey: .position)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(hexColor, forKey: .hexColor)
        try super.encode(to: encoder)
    }

    override func duplicate(withOffset offset: CGPoint) -> TextAnnotation {
        .init(text: text, position: position.addTo(offset), fontSize: fontSize, color: color)
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? TextAnnotation else { return false }
        if id != rhs.id { return false }
        if text != rhs.text { return false }
        if position != rhs.position { return false }
        if fontSize != rhs.fontSize { return false }
        if hexColor != rhs.hexColor { return false }
        return true
    }

    /// Deep copy of the annotation
    override func copy(with _: NSZone? = nil) -> Any {
        TextAnnotation(
            id: id,
            text: text,
            position: position,
            fontSize: fontSize,
            color: color
        )
    }
}
