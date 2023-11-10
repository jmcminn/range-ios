import Foundation
import UIKit

enum ScribbleAnnotationRenderer {
    /// Renders the ScribbleAnnotation
    static func render(_ scribble: ScribbleAnnotation) {
        render(path: scribble.path.getUIBezierPath(), lineWidth: scribble.lineWidth, color: scribble.color)
    }

    /// Renders scribble with given parameters (to be reused in ScribbleView)
    static func render(path: UIBezierPath, lineWidth: CGFloat, color: UIColor) {
        path.lineJoinStyle = .round
        path.lineCapStyle = .round

        // outline
        path.lineWidth = 2 * lineWidth
        // if scribble color is white then we outline with black
        if color.hexString == UIColor.white.hexString {
            UIColor.black.set()
        } else {
            UIColor.white.set()
        }
        path.stroke()

        // line
        path.lineWidth = lineWidth
        color.set()
        path.stroke()
    }
}
