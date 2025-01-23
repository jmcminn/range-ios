import Foundation
import UIKit

/// Annotations related definitions
extension Annotations {
    /// The scale property of the Annotations is calculated based on this property, so scale = min(imageHeight, imageWidth)/referenceViewSize
    static let referenceViewSize: Double = 400.0

    /// Scribble/arrow thickness, independent of the image size
    /// The exact thickness in pixels depends on the scale used for annotations (which is dependent on the image size)
    static let lineThicknessOptions: [Double] = [0.5, 1, 1.5, 2, 2.5, 3, 4.5, 6, 9, 12]
    static let defaultLineThickness: Double = 6

    /// Given the value find the nearest index in the lineThicknessOptions (the value may be not an exact value from the options array)
    static func lineThicknessOptionIndex(forValue value: Double) -> Int {
        let distances = lineThicknessOptions.map { abs($0 - value) }
        if let minDistance = distances.min(), let index = distances.firstIndex(of: minDistance) {
            return index
        }
        return lineThicknessOptions.firstIndex(of: defaultLineThickness) ?? 0
    }

    /// Colors for color picker
    static let colors: [UIColor] = [
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
    static let fontSizeOptions: [Double] = [4, 5.5, 7, 8.5, 10, 12, 16, 20, 26, 32]
    static let defaultFontSize: Double = 20

    /// Given the value find the nearest index in the fontSizeOptions (the value may be not an exact value from the options array)
    static func fontSizeOptionIndex(forValue value: Double) -> Int {
        let distances = fontSizeOptions.map { abs($0 - value) }
        if let minDistance = distances.min(), let index = distances.firstIndex(of: minDistance) {
            return index
        }
        return fontSizeOptions.firstIndex(of: defaultFontSize) ?? 0
    }

    /// Text padding based on fontSize.
    /// The size of the white background = text size + textPadding on each side.
    static func textHorizontalPadding(forFontSize fontSize: Double) -> Double { fontSize / 5.0 }
    static func textVerticalPadding(forFontSize fontSize: Double) -> Double { fontSize / 30.0 }

    /// The corner radius of the white text annotation box.
    static func textBoxCornerRadius(forFontSize fontSize: Double) -> Double { fontSize / 5.0 }

    /// Unscaled offset to add to x/y position of annotation when duplicating it
    static let duplicateAnnotationOffset: Double = 20.0
}
