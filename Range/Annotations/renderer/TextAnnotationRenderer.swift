import Foundation
import UIKit

enum TextAnnotationRenderer {
    /// The initial size for the box when calculating the annotation placement and the selection box when the text is empty (before user started typing)
    /// Unscaled
    static var emptyTextBoxWidth: CGFloat = 84.0

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
            annotationScale: annotationsGeometry.scale,
            backgroundOnly: false,
            renderShadow: true
        )
    }

    /// Renders text with given parameters (to be reused in TextAnnotationView). It requires the parameters in proper scale
    /// - Parameters:
    ///   - fontSize a SCALED font size, the scale is only applied to constants
    ///   - annotationScale required to render the unscaled constants
    ///   - backgroundOnly when editing the text we only want the renderer to show the background as the text is displayed in a UITextView
    ///   - renderShadow whether the background should have the shadow, when rendering in a UIView the shadow is not rendered here as the UIView draw cannot draw outside of bounds so it needs to add shadow itself
    ///   - renderingOffset - When rendering in TextAnnotationView the rendering must be done in view local coordinates. We still need the real position to calculate the text wrapping but then the renderer should offset all the operations by renderingOffset (which is just -position)
    static func render(
        text: String,
        position: CGPoint,
        fontSize: Double,
        color: UIColor,
        annotationScale: Double,
        backgroundOnly: Bool,
        renderShadow: Bool,
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
            text: text,
            fontSize: fontSize,
            annotationScale: annotationScale
        )
        let cornerRadius = Annotations.textBoxCornerRadius * annotationScale
        let backgroundRect = UIBezierPath(
            roundedRect: CGRect(origin: position.addTo(renderingOffset), size: annotationSize),
            byRoundingCorners: .allCorners,
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
        if renderShadow {
            UIGraphicsGetCurrentContext()?
                .setShadow(offset: .init(width: 2, height: 2), blur: 4,
                           color: UIColor.Neutral_10.withAlphaComponent(0.25).cgColor)
        }
        backgroundRect.fill()
        UIGraphicsGetCurrentContext()?.setShadow(offset: .zero, blur: 0, color: nil)

        // text
        if !backgroundOnly {
            color.set()
            let textFontAttributes = [
                NSAttributedString.Key.font: annotationFont(ofSize: fontSize),
                NSAttributedString.Key.foregroundColor: color,
            ] as [NSAttributedString.Key: Any]

            let textHorizontalPadding = ceil(Annotations.textHorizontalPadding * annotationScale)
            let textVerticalPadding = ceil(Annotations.textVerticalPadding * annotationScale)
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
        UIFont(name: "Inter-Bold", size: size)!
    }

    /// Calculates the size of the annotation for given text with given font. Adds padding for the white box.
    ///
    /// For empty text adjusts width using `TextAnnotationRenderer.emptyTextBoxWidth`
    ///
    /// - Parameters:
    ///   - fontSize a SCALED font size, the scale is only applied to constants
    ///   - annotationScale to be used for unscaled constants that are not stored in the TextAnnotation (corner radius, padding)
    static func annotationSize(
        text: String,
        fontSize: Double,
        annotationScale: Double
    ) -> CGSize {
        var textSize = TextAnnotationRenderer.textSize(text: text, fontSize: fontSize)
        // make empty text box take some initial width
        if text.isEmpty {
            textSize.width = max(textSize.width, ceil(emptyTextBoxWidth * annotationScale))
        }

        let textHorizontalPadding = ceil(Annotations.textHorizontalPadding * annotationScale)
        let textVerticalPadding = ceil(Annotations.textVerticalPadding * annotationScale)

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
    fileprivate static func textSize(text: String, fontSize: Double,
                                     maxWidth: CGFloat = .greatestFiniteMagnitude) -> CGSize
    {
        let font = annotationFont(ofSize: fontSize)
        let textSize = text._boundingBox(font: font, maxWidth: maxWidth)
        return CGSize(width: ceil(textSize.width), height: ceil(textSize.height))
    }
}
