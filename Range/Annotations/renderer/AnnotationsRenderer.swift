import Foundation
import UIKit

/// Namespace for annotations rendering
enum AnnotationsRenderer {
    /// Render all annotaitons on given image and return resulting JPEG data
    static func render(annotations: Annotations, onImage image: UIImage) -> Data {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(
            size: size,
            // keep the original scale (changing the scale here would change the image resolution):
            format: UIGraphicsImageRendererFormat(for: UITraitCollection(displayScale: 1))
        )
        return renderer.jpegData(withCompressionQuality: 0.75) { _ in
            let drawRect = CGRect(origin: .zero, size: size)
            image.draw(in: drawRect)

            let annotationsGeometry = AnnotationsGeometry(
                imageWidth: annotations.width,
                imageHeight: annotations.height,
                scale: annotations.scale
            )
            annotations.annotations.forEach { annotation in
                if let arrow = annotation as? ArrowAnnotation {
                    ArrowAnnotationRenderer.render(arrow, annotationsGeometry: annotationsGeometry)
                } else if let scribble = annotation as? ScribbleAnnotation {
                    ScribbleAnnotationRenderer.render(scribble)
                } else if let text = annotation as? TextAnnotation {
                    TextAnnotationRenderer.render(text, annotationsGeometry: annotationsGeometry)
                } else {
                    fatalError("Rendering of annotation type \(annotation) is not supported")
                }
            }
        }
    }
}
