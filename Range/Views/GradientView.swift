import Foundation
import UIKit

/// A UIView subclass using CAGradientLayer as its layer
class GradientView: UIView {
    override open class var layerClass: AnyClass {
        CAGradientLayer.classForCoder()
    }

    var gradientLayer: CAGradientLayer {
        layer as! CAGradientLayer
    }
}
