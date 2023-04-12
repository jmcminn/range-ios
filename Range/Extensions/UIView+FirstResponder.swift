import Foundation
import UIKit

/// Extension to find the first responder subview of this view
extension UIView {
    var _firstResponder: UIView? {
        guard !isFirstResponder else { return self }
        for subview in subviews {
            if let firstResponder = subview._firstResponder {
                return firstResponder
            }
        }
        return nil
    }
}
