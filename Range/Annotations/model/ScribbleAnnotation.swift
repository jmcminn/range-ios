import Foundation
import UIKit

/// Definition of a scribble drawing
class ScribbleAnnotation: NSObject, Codable {
    /// The unique id of the annotation
    let id: String
    /// Type, it's not `let` so it's encoded/decoded
    private(set) var type: AnnotationType = .scribble
    /// Path in the image coordinates space
    var path: RangeBezierPath
    /// scribble thickness
    var lineWidth: Double
    /// the storage for color, String so it can be encoded/decoded
    private var hexColor: String
    /// inner color (the outline is always white) - UIColor wrapping the hexColor
    @objc dynamic var color: UIColor {
        get { UIColor(hexString: hexColor) }
        set { hexColor = newValue.hexString }
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
}

extension ScribbleAnnotation: AnnotationConvertible {
    public var annotation: Annotation { .scribble(self) }
}
