import UIKit

/// Extension adding shadows defined in Figma.
extension UIView {
    func addDropshadowMd01() {
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 10)
    }

    func addDropshadowMd02() {
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 10)
    }
}
