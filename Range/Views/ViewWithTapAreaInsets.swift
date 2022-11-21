import UIKit

/// Extension of UIView that allows to set tapInset to allow tapping outside of a button (for small buttons for which
/// we need bigger tap area than the button frame size)
class ViewWithTapAreaInsets: UIView {
    /// insets for tap area, to make the tap area larger provide negative values
    var tapAreaInsets: UIEdgeInsets = .zero

    /// "builder" like function to return button with insets
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
