import Foundation
import UIKit

/// Definition of an arrow annotation
class ArrowAnnotation: NSObject, Codable {
    /// The name for the notification posted in NotificationCenter when the annotation changes
    static let UpdateNotificationName = Notification.Name("io.range.App.ArrowAnnotationChanged")

    /// The unique id of the annotation
    let id: String
    /// Type, it's not `let` so it's encoded/decoded
    private(set) var type: AnnotationType = .arrow
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
    @objc dynamic var color: UIColor {
        get { UIColor(hexString: hexColor) ?? .black }
        set {
            hexColor = newValue.hexString
            postUpdate()
        }
    }

    init(
        id: String = UUID().uuidString.lowercased(),
        startPoint: CGPoint,
        endPoint: CGPoint,
        lineWidth: Double,
        color: UIColor
    ) {
        self.id = id
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.lineWidth = lineWidth
        hexColor = color.hexString
    }

    func duplicate(withOffset offset: CGPoint) -> ArrowAnnotation {
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

    override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(id)
        return hasher.finalize()
    }

    /// Use notification center to post the notification about update in filters
    private func postUpdate() {
        NotificationCenter.default.post(name: ArrowAnnotation.UpdateNotificationName, object: id)
    }
}

extension ArrowAnnotation: NSCopying {
    /// Deep copy of the annotation
    func copy(with _: NSZone? = nil) -> Any {
        ArrowAnnotation(
            id: id,
            startPoint: startPoint,
            endPoint: endPoint,
            lineWidth: lineWidth,
            color: color
        )
    }
}

extension ArrowAnnotation: AnnotationConvertible {
    public var annotation: Annotation { .arrow(self) }
}
