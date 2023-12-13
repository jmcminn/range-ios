import Foundation
import UIKit

/// Definition of a text box annotation
class TextAnnotation: NSObject, Codable {
    /// The name for the notification posted in NotificationCenter when the annotation changes
    static let UpdateNotificationName = Notification.Name("io.range.App.TextAnnotationChanged")

    /// The unique id of the annotation
    let id: String
    /// Type, it's not `let` so it's encoded/decoded
    private(set) var type: AnnotationType = .text
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
    func fontSizeEnum(_ annotationsGeometry: AnnotationsGeometry) -> Annotations.FontSize? {
        let unscaledFontSize = fontSize / annotationsGeometry.scale
        return Annotations.FontSize.allCases.first { $0.size == unscaledFontSize }
    }

    /// the storage for color, String so it can be encoded/decoded
    private(set) var hexColor: String
    /// inner color (the outline is always white) - UIColor wrapping the hexColor
    @objc dynamic var color: UIColor {
        get { UIColor(hexString: hexColor) ?? .black }
        set {
            hexColor = newValue.hexString
            postUpdate()
        }
    }

    init(
        id: String = UUID().uuidString.lowercased(),
        text: String,
        position: CGPoint,
        fontSize: Double,
        color: UIColor
    ) {
        self.id = id
        self.text = text
        self.position = position.roundCoordinates()
        self.fontSize = fontSize
        hexColor = color.hexString
    }

    func duplicate(withOffset offset: CGPoint) -> TextAnnotation {
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

    override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(id)
        return hasher.finalize()
    }

    /// Use notification center to post the notification about update in filters
    private func postUpdate() {
        NotificationCenter.default.post(name: TextAnnotation.UpdateNotificationName, object: id)
    }
}

extension TextAnnotation: NSCopying {
    /// Deep copy of the annotation
    func copy(with _: NSZone? = nil) -> Any {
        TextAnnotation(
            id: id,
            text: text,
            position: position,
            fontSize: fontSize,
            color: color
        )
    }
}

extension TextAnnotation: AnnotationConvertible {
    public var annotation: Annotation { .text(self) }
}
