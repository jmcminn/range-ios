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

            annotations.annotations.forEach { annotation in
                switch annotation {
                case let .scribble(scribble):
                    ScribbleAnnotationRenderer.render(scribble)
                case let .text(text):
                    TextAnnotationRenderer.render(text, annotationsScale: annotations.scale)
                }
            }
        }
    }
}
