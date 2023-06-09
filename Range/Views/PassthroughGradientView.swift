import UIKit

/// Passes all touches to the next view (if any), in the view stack.
/// Uses CAGradientLayer as its layer
class PassthroughGradientView: UIView {
    override open class var layerClass: AnyClass {
        CAGradientLayer.classForCoder()
    }

    var gradientLayer: CAGradientLayer {
        layer as! CAGradientLayer
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        subviews.contains { subview in
            subview.hitTest(convert(point, to: subview), with: event) != nil
        }
    }
}
