import UIKit

private var associateKey: Void?

extension UIScrollView {
    var headerExpander: HeaderExpander? {
        get {
            objc_getAssociatedObject(self, &associateKey) as? HeaderExpander
        }
        set {
            objc_setAssociatedObject(self, &associateKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}
