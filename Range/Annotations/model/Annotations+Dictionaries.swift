import Foundation
import UIKit

/// Annotations related definitions
extension Annotations {
    /// The scale property of the Annotations is calculated based on this property, so scale = min(imageHeight, imageWidth)/referenceViewSize
    static var referenceViewSize: Double = 400.0

    /// Scribble/arrow thickness, independent of the image size
    /// The exact thickness in pixels depends on the scale used for annotations (which is dependent on the image size)
    static var lineThicknessOptions: [Double] = [0.5, 1, 1.5, 2, 2.5, 3, 4.5, 6, 9, 12]
    static var defaultLineThickness: Double = 6.0

    /// Given the value find the nearest index in the lineThicknessOptions (the value may be not an exact value from the options array)
    static func lineThicknessOptionIndex(forValue value: Double) -> Int {
        let distances = lineThicknessOptions.map { abs($0 - value) }
        if let minDistance = distances.min(), let index = distances.firstIndex(of: minDistance) {
            return index
        }
        return lineThicknessOptions.firstIndex(of: defaultLineThickness) ?? 0
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
