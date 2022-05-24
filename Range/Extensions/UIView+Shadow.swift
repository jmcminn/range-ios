import UIKit

/// Extension adding shadows defined in Figma.
extension UIView {
    /// Translation from Figma parameters to layer properties
    func setShadowWithFigmaValues(x: CGFloat = 0, y: CGFloat, blur: CGFloat, opacity: Float) {
        layer.shadowOffset = CGSize(width: x, height: y)
        layer.shadowRadius = blur / 2.0
        layer.shadowOpacity = opacity
        layer.shadowColor = UIColor.Neutral_10.cgColor
    }
}
