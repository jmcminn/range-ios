import Foundation

/// Namesoace for annotations related definitions
enum Annotations {
    /// Scribble thickness, independent of the image size
    /// The exact thickness in pixels depends on the scale used for annotations (which is dependent on the image size)
    enum ScribbleThickness: String, CaseIterable {
        case thin, light, medium, bold, heavy

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
