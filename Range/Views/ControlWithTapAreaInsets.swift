import UIKit

/// Extension of UIControl that allows to set tapInset to allow tapping outside of a control (for small views for which
/// we need bigger tap area than the frame size)
class ControlWithTapAreaInsets: UIControl {
    /// insets for tap area, to make the tap area larger provide negative values
    var tapAreaInsets: UIEdgeInsets = .zero

    /// "builder" like function to return self with insets
    func withTapAreaInsets(_ insets: UIEdgeInsets) -> Self {
        tapAreaInsets = insets
        return self
    }

    override func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        let newArea = CGRect(
            x: bounds.origin.x + tapAreaInsets.left,
            y: bounds.origin.y + tapAreaInsets.top,
            width: bounds.size.width - tapAreaInsets.left - tapAreaInsets.right,
            height: bounds.size.height - tapAreaInsets.top - tapAreaInsets.bottom
        )
        return newArea.contains(point)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
