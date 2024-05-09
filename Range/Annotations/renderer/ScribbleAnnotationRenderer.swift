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
        // shadow for the outline
        UIGraphicsGetCurrentContext()?
            .setShadow(offset: .init(width: 0, height: 2), blur: 8,
                       color: UIColor.Neutral_10.withAlphaComponent(0.25).cgColor)
        path.stroke()
        UIGraphicsGetCurrentContext()?.setShadow(offset: .zero, blur: 0, color: nil)

        // line
        path.lineWidth = lineWidth
        color.set()
        path.stroke()
    }
}
