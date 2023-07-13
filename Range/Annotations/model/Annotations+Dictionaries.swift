import Foundation
import UIKit

/// Annotations related definitions
enum Annotations {
    /// Scribble thickness, independent of the image size
    /// The exact thickness in pixels depends on the scale used for annotations (which is dependent on the image size)
    enum ScribbleThickness: String, CaseIterable, Codable {
        case thin, light, medium, bold, heavy

        /// When rendering the scribble this is the width of the inner line, the outline is hardcoded to be `2 * lineWidth`
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

    /// Colors for scribble color picker
    static var scribbleColors: [UIColor] = [
        .white,
        .black,
        .Primary_Blue_04,
        .Pink_03,
        .Orange_03,
        .Red_03,
        .Green_03,
    ]
}
