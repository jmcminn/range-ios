import Foundation
import UIKit

enum ArrowAnnotationRenderer {
    /// Renders the ArrowAnnotation
    static func render(_ arrow: ArrowAnnotation, annotationsGeometry: AnnotationsGeometry) {
        // reuse Scribble renderer as arrow can be visualized as a UIBezierPath
        ScribbleAnnotationRenderer.render(
            path: RangeBezierPath.arrowPath(
                startPoint: arrow.startPoint,
                endPoint: arrow.endPoint,
                tipLength: Annotations.arrowTipLength * annotationsGeometry.scale
            ).getUIBezierPath(),
            lineWidth: arrow.lineWidth,
            color: arrow.color
        )
    }
}
