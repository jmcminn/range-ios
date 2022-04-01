import UIKit

extension UIScrollView {
    var scrollsUp: Bool {
        self.panGestureRecognizer.velocity(in: nil).y < 0
    }
    
    var isContentOriginInBounds: Bool {
        self.contentOffset.y <= -self.contentInset.top
    }
}
