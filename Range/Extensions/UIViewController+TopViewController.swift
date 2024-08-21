import Foundation
import UIKit

extension UIViewController {
    /// Find the presented top view controller recursively starting from the this view controller
    func _topViewController() -> UIViewController {
        if let navigationController = self as? UINavigationController {
            return navigationController.visibleViewController?._topViewController() ?? self
        } else if let tabBarController = self as? UITabBarController {
            return tabBarController.selectedViewController?._topViewController() ?? self
        } else if let presentedViewController = presentedViewController, !presentedViewController.isBeingDismissed {
            return presentedViewController._topViewController()
        } else {
            return self
        }
    }
    
    /// Find the root view controller
    func _rootViewController() -> UIViewController {
        if let presentingViewController {
            return presentingViewController._rootViewController()
        } else if let navigationController {
            return navigationController._rootViewController()
        } else if let parent {
            return parent._rootViewController()
        }
        return self
    }
}
