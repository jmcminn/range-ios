import UIKit

extension UIScrollView {
    var scrollsUp: Bool {
        panGestureRecognizer.velocity(in: nil).y < 0
    }

    var isContentOriginInBounds: Bool {
        contentOffset.y <= -contentInset.top
    }
}
