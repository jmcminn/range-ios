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
        UIColor.white.set()
        path.stroke()

        // line
        path.lineWidth = lineWidth
        color.set()
        path.stroke()
    }
}
