import Foundation
import UIKit

enum TextAnnotationRenderer {
    /// Renders the TextAnnotation
    /// - Parameters:
    ///    - text text annotation, it's values are scaled
    ///    - annotationsGeometry geometry.scale required to render the unscaled constants, geometry.width required to calculate the box size and text wrapping
    static func render(_ text: TextAnnotation, annotationsGeometry: AnnotationsGeometry) {
        render(
            text: text.text,
            position: text.position,
            fontSize: text.fontSize,
            color: text.color,
            annotationsGeometry: annotationsGeometry,
            backgroundOnly: false
        )
    }

    /// Renders text with given parameters (to be reused in TextAnnotationView). It requires the parameters in proper scale
    /// - Parameters:
    ///   - fontSize a SCALED font size, the scale is only applied to constants
    ///   - annotationsGeometry geometry.scale required to render the unscaled constants, geometry.width required to calculate the box size and text wrapping
    ///   - backgroundOnly when editing the text we only want the renderer to show the background as the text is displayed in a UITextView
    ///   - renderingOffset - When rendering in TextAnnotationView the rendering must be done in view local coordinates. We still need the real position to calculate the text wrapping but then the renderer should offset all the operations by renderingOffset (which is just -position)
    static func render(
        text: String,
        position: CGPoint,
        fontSize: Double,
        color: UIColor,
        annotationsGeometry: AnnotationsGeometry,
        backgroundOnly: Bool,
        renderingOffset: CGPoint = .zero
    ) {
        // background
        // box is black for white text, for all other colors it's white
        if color.hexString == UIColor.white.hexString {
            UIColor.black.set()
        } else {
            UIColor.white.set()
        }
        let annotationSize = annotationSize(
            position: position,
            text: text,
            fontSize: fontSize,
            annotationsGeometry: annotationsGeometry
        )
        let cornerRadius = Annotations.textBoxCornerRadius * annotationsGeometry.scale
        let backgroundRect = UIBezierPath(
            roundedRect: CGRect(origin: position.addTo(renderingOffset), size: annotationSize),
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

            let textHorizontalPadding = ceil(Annotations.textHorizontalPadding * annotationsGeometry.scale)
            let textVerticalPadding = ceil(Annotations.textVerticalPadding * annotationsGeometry.scale)
            let textRect = CGRect(
                origin: position.translate(x: textHorizontalPadding, y: textVerticalPadding).addTo(renderingOffset),
                size: CGSize(
                    width: annotationSize.width - 2 * textHorizontalPadding,
                    height: annotationSize.height - 2 * textVerticalPadding
                )
            )
            text.draw(in: textRect, withAttributes: textFontAttributes)
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
        position: CGPoint,
        text: String,
        fontSize: Double,
        annotationsGeometry: AnnotationsGeometry
    ) -> CGSize {
        let textHorizontalPadding = ceil(Annotations.textHorizontalPadding * annotationsGeometry.scale)
        let textVerticalPadding = ceil(Annotations.textVerticalPadding * annotationsGeometry.scale)
        // we want the text to wrap on the edge of the photo, so we need to constrain the width (accounting for padding)
        let maxTextWidth = Double(annotationsGeometry.imageWidth) - position.x - 2 * textHorizontalPadding
        let textSize = TextAnnotationRenderer.textSize(text: text, fontSize: fontSize, maxWidth: maxTextWidth)
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
    fileprivate static func textSize(text: String, fontSize: Double, maxWidth: CGFloat) -> CGSize {
        let font = annotationFont(ofSize: fontSize)
        let textSize = text._boundingBox(font: font, maxWidth: maxWidth)
        return CGSize(width: ceil(textSize.width), height: ceil(textSize.height))
    }
}
