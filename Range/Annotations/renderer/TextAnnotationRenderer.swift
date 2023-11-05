import Foundation
import UIKit

enum TextAnnotationRenderer {
    /// Renders the TextAnnotation
    /// - Parameters:
    ///    - text text annotation, it's values are scaled
    ///    - scale to be used for unscaled constants that are not stored in the TextAnnotation (corner radius, padding)
    static func render(_ text: TextAnnotation, scale: Double) {
        render(
            text: text.text,
            position: text.position,
            fontSize: text.fontSize,
            color: text.color,
            scale: scale,
            backgroundOnly: false
        )
    }

    // TODO: 1981 store text padding (scaled) in TextAnnotation??? so it can be directly used in renderer?
    /// Renders text with given parameters (to be reused in TextAnnotationView). It requires the parameters in proper scale
    /// - Parameters:
    ///   - fontSize a SCALED font size, the scale is only applied to constants
    ///   - scale to be used for unscaled constants that are not stored in the TextAnnotation (corner radius, padding)
    ///   - backgroundOnly when editing the text we only want the renderer to show the background as the text is displayed in a UITextView
    static func render(
        text: String,
        position: CGPoint,
        fontSize: Double,
        color: UIColor,
        scale: Double,
        backgroundOnly: Bool
    ) {
        // background
        UIColor.white.set()
        let annotationSize = annotationSize(text: text, fontSize: fontSize, scale: scale)
        let cornerRadius = Annotations.textBoxCornerRadius * scale
        let backgroundRect = UIBezierPath(
            roundedRect: CGRect(origin: position, size: annotationSize),
            byRoundingCorners: .allCorners,
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
        backgroundRect.fill()

        // text
        if !backgroundOnly {
            color.set()
            let textFontAttributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: fontSize),
                NSAttributedString.Key.foregroundColor: color,
            ] as [NSAttributedString.Key: Any]
            let textPadding = ceil(Annotations.textPadding * scale)
            text.draw(
                in: CGRect(
                    origin: position.translate(x: textPadding, y: textPadding),
                    size: textSize(text: text, fontSize: fontSize)
                ),
                withAttributes: textFontAttributes
            )
        }
    }
}

extension TextAnnotationRenderer {
    /// Calculates the size of the annotation for given text with given font. Adds padding for the white box.
    /// - Parameters:
    ///   - fontSize a SCALED font size, the scale is only applied to constants
    ///   - scale to be used for unscaled constants that are not stored in the TextAnnotation (corner radius, padding)
    static func annotationSize(
        text: String,
        fontSize: Double,
        scale: Double
    ) -> CGSize {
        let textSize = TextAnnotationRenderer.textSize(text: text, fontSize: fontSize)
        let scaledPadding = ceil(Annotations.textPadding * scale)
        let boxSize = CGSize(
            width: textSize.width + 2 * scaledPadding,
            height: textSize.height + 2 * scaledPadding
        )
        return boxSize
    }

    /// Calculates the size of the text.
    /// Returns the size with width and height rounded up to Int
    /// - Parameters:
    ///   - fontSize a SCALED font size, the scale is only applied to constants
    static func textSize(text: String, fontSize: Double) -> CGSize {
        let font = UIFont.systemFont(ofSize: fontSize)
        let textSize = text._boundingBox(font: font)
        return CGSize(width: ceil(textSize.width), height: ceil(textSize.height))
    }
}
