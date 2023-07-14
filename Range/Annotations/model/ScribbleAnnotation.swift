import Foundation
import UIKit

/// Definition of a scribble drawing
class ScribbleAnnotation: NSObject, Codable {
    /// The name for the notification posted in NotificationCenter when the annotation changes
    static let UpdateNotificationName = Notification.Name("io.range.App.ScribbleAnnotationChanged")

    /// The unique id of the annotation
    let id: String
    /// Type, it's not `let` so it's encoded/decoded
    private(set) var type: AnnotationType = .scribble
    /// Path in the image coordinates space
    var path: RangeBezierPath { didSet { postUpdate() }}
    /// scribble thickness
    var lineWidth: Double { didSet { postUpdate() }}
    /// the storage for color, String so it can be encoded/decoded
    private var hexColor: String
    /// inner color (the outline is always white) - UIColor wrapping the hexColor
    @objc dynamic var color: UIColor {
        get { UIColor(hexString: hexColor) }
        set {
            hexColor = newValue.hexString
            postUpdate()
        }
    }

    init(
        id: String = UUID().uuidString.lowercased(),
        path: RangeBezierPath,
        lineWidth: Double,
        color: UIColor
    ) {
        self.id = id
        self.path = path
        self.lineWidth = lineWidth
        hexColor = color.hexString
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? ScribbleAnnotation else { return false }
        if id != rhs.id { return false }
        if path != rhs.path { return false }
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
        NotificationCenter.default.post(name: ScribbleAnnotation.UpdateNotificationName, object: id)
    }
}

extension ScribbleAnnotation: NSCopying {
    /// Deep copy of the annotation
    func copy(with _: NSZone? = nil) -> Any {
        ScribbleAnnotation(id: id, path: path.copy() as! RangeBezierPath, lineWidth: lineWidth, color: color)
    }
}

extension ScribbleAnnotation: AnnotationConvertible {
    public var annotation: Annotation { .scribble(self) }
}
