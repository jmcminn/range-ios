import UIKit

private var associateKey: Void?

/// Objective-C associated object technique for adding new stored properties to classes.
/// This is a little hacky but it's convenient to store the UIScrollViewDelegateProxy in the UIScrollView
extension UIScrollView {
    var proxy: UIScrollViewDelegateProxy? {
        get {
            objc_getAssociatedObject(self, &associateKey) as? UIScrollViewDelegateProxy
        }
        set {
            objc_setAssociatedObject(self, &associateKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    /// Install UIScrollViewDelegateProxy on this scroll view to forward delegate invocations to `forwardToDelegate`
    /// This can be called multiple times with different delegates, the UIScrollViewDelegateProxy will be reused.
    func forwardDelegateInvocations(to forwardToDelegate: UIScrollViewDelegate) {
        if let proxy = delegate as? UIScrollViewDelegateProxy {
            /// the proxy is already installed
            proxy.forward(to: forwardToDelegate)
        } else {
            /// install new proxy
            let proxy = UIScrollViewDelegateProxy(scrollView: self)
            proxy.forward(to: forwardToDelegate)
            // because UIScrollView.delegate is a weak instance we need to store it strongly too:
            self.proxy = proxy
        }
    }

    /// Removes given `forwardToDelegate` from the list of delegates the UIScrollViewDelegateProxy installed on this
    /// scroll view forwards to. If this is the last forward delegate the proxy is removed from the scroll view.
    func cancelForwardingDelegateInvocations(to forwardToDelegate: UIScrollViewDelegate) {
        // this should return proxy but ignore if not
        guard let proxy = delegate as? UIScrollViewDelegateProxy else { return }
        proxy.cancelForwarding(to: forwardToDelegate)

        // remove the associated object if not forwarding anymore
        if !proxy.isForwarding {
            self.proxy = nil
        }
    }
}

/// This class replaces the original delegate on a provided UIScrollView and dispatches the calls to both,
/// the original and the "forwardTo" delegate.
class UIScrollViewDelegateProxy: NSObject, UIScrollViewDelegate {
    /// observation token to deregister
    private var scrollViewObservation: NSKeyValueObservation?
    /// scroll view this proxy is attached to
    private unowned let scrollView: UIScrollView
    /// original delegate to be restored when this proxy is uninstalled from the scroll view
    private weak var originalDelegate: UIScrollViewDelegate?
    /// the delegate to forward to
    private var forwardToDelegates = NSHashTable<UIScrollViewDelegate>.weakObjects()

    /// is this proxy forwarding to any delegates
    var isForwarding: Bool {
        !forwardToDelegates.allObjects.isEmpty
    }

    /// creates and installs the proxy on the scroll view
    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
        originalDelegate = scrollView.delegate
        super.init()
        scrollView.delegate = self
        // handle change of original delegate
        scrollViewObservation = scrollView.observe(\.delegate) { [weak self] scrollView, _ in
            guard !(scrollView.delegate === self) else { return }
            self?.originalDelegate = scrollView.delegate
            scrollView.delegate = self
        }
    }

    deinit {
        uninstall()
    }

    /// respond to all calls for functions either provided in this proxy or in the original delegate
    override func responds(to aSelector: Selector!) -> Bool {
        let originalDelegateRespondsToSelector = originalDelegate?.responds(to: aSelector) ?? false
        return super.responds(to: aSelector) || originalDelegateRespondsToSelector
    }

    /// part of message routing in ObjC - it's where the unrecognized messages should go
    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if originalDelegate?.responds(to: aSelector) == true {
            return originalDelegate
        } else {
            return super.forwardingTarget(for: aSelector)
        }
    }

    func forward(to forwardToDelegate: UIScrollViewDelegate) {
        forwardToDelegates.add(forwardToDelegate)
    }

    func cancelForwarding(to forwardToDelegate: UIScrollViewDelegate) {
        forwardToDelegates.remove(forwardToDelegate)
        if !isForwarding {
            uninstall()
        }
    }

    private func uninstall() {
        scrollViewObservation?.invalidate()
        forwardToDelegates.removeAllObjects()
        scrollViewObservation?.invalidate()
        scrollView.delegate = originalDelegate
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        forwardToDelegates.allObjects.forEach { $0.scrollViewDidScroll?(scrollView) }
        originalDelegate?.scrollViewDidScroll?(scrollView)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        forwardToDelegates.allObjects.forEach { $0.scrollViewWillBeginDragging?(scrollView) }
        originalDelegate?.scrollViewWillBeginDragging?(scrollView)
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>)
    {
        forwardToDelegates.allObjects
            .forEach {
                $0.scrollViewWillEndDragging?(
                    scrollView,
                    withVelocity: velocity,
                    targetContentOffset: targetContentOffset
                )
            }
        originalDelegate?.scrollViewWillEndDragging?(scrollView,
                                                     withVelocity: velocity,
                                                     targetContentOffset: targetContentOffset)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        forwardToDelegates.allObjects.forEach { $0.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate) }
        originalDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        forwardToDelegates.allObjects.forEach { $0.scrollViewDidEndDecelerating?(scrollView) }
        originalDelegate?.scrollViewDidEndDecelerating?(scrollView)
    }
}
