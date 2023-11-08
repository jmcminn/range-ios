import Foundation
import UIKit

enum TextAnnotationRenderer {
    /// Renders the TextAnnotation
    /// - Parameters:
    ///    - text text annotation, it's values are scaled
    ///    - annotationsScale to be used for unscaled constants that are not stored in the TextAnnotation (corner radius, padding)
    static func render(_ text: TextAnnotation, annotationsScale: Double) {
        render(
            text: text.text,
            position: text.position,
            fontSize: text.fontSize,
            color: text.color,
            annotationsScale: annotationsScale,
            backgroundOnly: false
        )
    }

    /// Renders text with given parameters (to be reused in TextAnnotationView). It requires the parameters in proper scale
    /// - Parameters:
    ///   - fontSize a SCALED font size, the scale is only applied to constants
    ///   - annotationsScale to be used for unscaled constants that are not stored in the TextAnnotation (corner radius, padding)
    ///   - backgroundOnly when editing the text we only want the renderer to show the background as the text is displayed in a UITextView
    static func render(
        text: String,
        position: CGPoint,
        fontSize: Double,
        color: UIColor,
        annotationsScale: Double,
        backgroundOnly: Bool
    ) {
        // background
        UIColor.white.set()
        let annotationSize = annotationSize(text: text, fontSize: fontSize, annotationsScale: annotationsScale)
        let cornerRadius = Annotations.textBoxCornerRadius * annotationsScale
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
                NSAttributedString.Key.font: annotationFont(ofSize: fontSize),
                NSAttributedString.Key.foregroundColor: color,
            ] as [NSAttributedString.Key: Any]
            let textHorizontalPadding = ceil(Annotations.textHorizontalPadding * annotationsScale)
            let textVerticalPadding = ceil(Annotations.textVerticalPadding * annotationsScale)
            text.draw(
                in: CGRect(
                    origin: position.translate(x: textHorizontalPadding, y: textVerticalPadding),
                    size: textSize(text: text, fontSize: fontSize)
                ),
                withAttributes: textFontAttributes
            )
        }
    }
}

extension TextAnnotationRenderer {
    /// Returns the font used for text annotations
    static func annotationFont(ofSize size: Double) -> UIFont {
        .systemFont(ofSize: size, weight: .heavy)
    }

    /// Calculates the size of the annotation for given text with given font. Adds padding for the white box.
    /// - Parameters:
    ///   - fontSize a SCALED font size, the scale is only applied to constants
    ///   - annotationsScale to be used for unscaled constants that are not stored in the TextAnnotation (corner radius, padding)
    static func annotationSize(
        text: String,
        fontSize: Double,
        annotationsScale: Double
    ) -> CGSize {
        let textSize = TextAnnotationRenderer.textSize(text: text, fontSize: fontSize)
        let textHorizontalPadding = ceil(Annotations.textHorizontalPadding * annotationsScale)
        let textVerticalPadding = ceil(Annotations.textVerticalPadding * annotationsScale)
        let boxSize = CGSize(
            width: textSize.width + 2 * textHorizontalPadding,
            height: textSize.height + 2 * textVerticalPadding
        )
        return boxSize
    }

    /// Calculates the size of the text.
    /// Returns the size with width and height rounded up to Int
    /// - Parameters:
    ///   - fontSize a SCALED font size, the scale is only applied to constants
    static func textSize(text: String, fontSize: Double) -> CGSize {
        let font = annotationFont(ofSize: fontSize)
        let textSize = text._boundingBox(font: font)
        return CGSize(width: ceil(textSize.width), height: ceil(textSize.height))
    }
}
