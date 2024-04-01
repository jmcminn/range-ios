import Foundation
import UIKit

enum LineAnnotationRenderer {
    /// Renders the LineAnnotation
    static func render(_ line: LineAnnotation, annotationsGeometry _: AnnotationsGeometry) {
        // reuse Scribble renderer as line can be visualized as a UIBezierPath
        ScribbleAnnotationRenderer.render(
            path: RangeBezierPath.linePath(
                startPoint: line.startPoint,
                endPoint: line.endPoint
            ).getUIBezierPath(),
            lineWidth: line.lineWidth,
            color: line.color
        )
    }
}
