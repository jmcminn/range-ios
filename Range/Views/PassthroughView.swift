import UIKit

/// Passing all touches to the next view (if any), in the view stack.
class PassthroughView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        subviews.contains { subview in
            subview.hitTest(convert(point, to: subview), with: event) != nil
        }
    }
}
