import UIKit

extension UIScrollView {
    var scrollsUp: Bool {
        panGestureRecognizer.velocity(in: nil).y < 0
    }

    /// whether the top of the content is below the top content inset, meaning the top of the content is visible or below the current
    /// visible viewport
    var isContentOriginInBounds: Bool {
        contentOffset.y <= -contentInset.top
    }
}
