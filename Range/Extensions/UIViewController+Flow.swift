import UIKit

extension UIViewController {
    func add(childController: UIViewController, toView: UIView? = nil) {
        addChild(childController)
        let viewToAddTo: UIView = toView ?? view
        viewToAddTo.addSubview(childController.view)
        childController.didMove(toParent: self)
    }

    func remove(childController: UIViewController) {
        childController.willMove(toParent: nil)
        childController.view.removeFromSuperview()
        childController.removeFromParent()
    }
}
