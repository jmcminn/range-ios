import UIKit

/// Extension adding shadows defined in Figma.
extension UIView {
    /// Translation from Figma parameters to layer properties
    func setShadowWithFigmaValues(x: CGFloat = 0, y: CGFloat, blur: CGFloat, opacity: Float) {
        layer.setShadowWithFigmaValues(x: x, y: y, blur: blur, opacity: opacity)
    }
}

extension CALayer {
    func setShadowWithFigmaValues(x: CGFloat = 0, y: CGFloat, blur: CGFloat, opacity: Float) {
        shadowOffset = CGSize(width: x, height: y)
        shadowRadius = blur / 2.0
        shadowOpacity = opacity
        shadowColor = UIColor.Neutral_10.cgColor
    }
}
