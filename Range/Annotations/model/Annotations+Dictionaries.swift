import Foundation
import UIKit

/// Annotations related definitions
extension Annotations {
    /// The scale property of the Annotations is calculated based on this property, so scale = min(imageHeight, imageWidth)/referenceViewSize
    static var referenceViewSize: Double = 400.0

    /// Scribble/arrow thickness, independent of the image size
    /// The exact thickness in pixels depends on the scale used for annotations (which is dependent on the image size)
    enum LineThickness: String, CaseIterable, Codable {
        case thin, light, medium, bold, heavy

        /// When rendering the scribble/arrow this is the width of the inner line, the outline is hardcoded to be `2 * lineWidth`
        /// This are reference values that don't include annotations scaling factor
        var lineWidth: CGFloat {
            switch self {
            case .thin: return 3.0
            case .light: return 4.5
            case .medium: return 6.0 // reference 100% value
            case .bold: return 9.0
            case .heavy: return 12.0
            }
        }

        /// width of the thickness option when presented in the annotations toolbar
        var toolbarWidth: CGFloat {
            switch self {
            case .thin: return 4
            case .light: return 6
            case .medium: return 8
            case .bold: return 10
            case .heavy: return 12
            }
        }
    }

    /// Colors for color picker
    static var colors: [UIColor] = [
        .white,
        .black,
        .Primary_Blue_04,
        .Pink_03,
        .Orange_03,
        .Red_03,
        .Green_03,
    ]

    /// text font size, independent of the image size
    /// The exact font size in pixels depends on the scale used for annotations (which is dependent on the image size)
    enum FontSize: String, CaseIterable, Codable {
        case extraSmall, small, medium, large, extraLarge

        /// This are reference values that don't include annotations scaling factor
        var size: CGFloat {
            switch self {
            case .extraSmall: return 12.0
            case .small: return 16.0
            case .medium: return 20.0 // reference 100% value
            case .large: return 26.0
            case .extraLarge: return 32.0
            }
        }

        /// size of the font selector image in the annotations toolbar
        var toolbarSize: CGFloat {
            switch self {
            case .extraSmall: return 12.0
            case .small: return 16.0
            case .medium: return 20.0 // reference 100% value
            case .large: return 26.0
            case .extraLarge: return 28.0
            }
        }
    }

    /// Default text padding for text annotations.
    /// Unscaled
    /// The size of the white background = text size + textPadding on each side.
    static var textHorizontalPadding: Double = 6.0
    static var textVerticalPadding: Double = 3.0

    /// The corner radius of the white text annotation box.
    /// Unscaled
    static var textBoxCornerRadius: Double = 6.0

    /// The length of a single arrow tip line (the angle between tip line and arrow line is 45deg)
    static var arrowTipLength: Double = 16.0

    /// Unscaled offset to add to x/y position of annotation when duplicating it
    static var duplicateAnnotationOffset: Double = 20.0
}
