import Foundation

/// Namesoace for annotations related definitions
enum Annotations {
    /// Scribble thickness, independent of the image size
    /// The exact thickness in pixels depends on the scale used for annotations (which is dependent on the image size)
    enum ScribbleThickness: String, CaseIterable {
        case thin, light, medium, bold, heavy

        /// When rendering the scribble this multiplier is used to adjust the base thickness
        var thicknessMultiplier: CGFloat {
            switch self {
            case .thin: return 0.5
            case .light: return 0.75
            case .medium: return 1.0 // reference 100% value
            case .bold: return 1.5
            case .heavy: return 2
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
}
