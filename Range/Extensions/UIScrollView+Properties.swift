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

    var isAtTop: Bool {
        contentOffset.y <= verticalOffsetForTop
    }

    var isAtBottom: Bool {
        contentOffset.y >= verticalOffsetForBottom
    }

    var verticalOffsetForTop: CGFloat {
        let topInset = contentInset.top
        return -topInset
    }

    var verticalOffsetForBottom: CGFloat {
        let scrollViewHeight = bounds.height
        let scrollContentSizeHeight = contentSize.height
        let bottomInset = contentInset.bottom
        let scrollViewBottomOffset = scrollContentSizeHeight + bottomInset - scrollViewHeight
        return scrollViewBottomOffset
    }
}
