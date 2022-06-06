import UIKit

/**
 This class replaces the original delegate on a provided UIScrollView and dispatches the calls to both, the original and the "forwardTo" delegate.
 */
class UIScrollViewDelegateProxy: NSObject, UIScrollViewDelegate {
    private var scrollViewObservation: NSKeyValueObservation?
    private weak var scrollView: UIScrollView?
    private weak var originalDelegate: UIScrollViewDelegate?
    private weak var forwardToDelegate: UIScrollViewDelegate?

    deinit {
        cancelForwarding()
    }

    override func responds(to aSelector: Selector!) -> Bool {
        let originalDelegateRespondsToSelector = originalDelegate?.responds(to: aSelector) ?? false
        return super.responds(to: aSelector) || originalDelegateRespondsToSelector
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if originalDelegate?.responds(to: aSelector) == true {
            return originalDelegate
        } else {
            return super.forwardingTarget(for: aSelector)
        }
    }

    func cancelForwarding() {
        cancelForwarding(restoresDelegate: true)
    }

    func forward(
        to forwardToDelegate: UIScrollViewDelegate,
        delegateInvocationsFrom scrollView: UIScrollView
    ) {
        guard !(scrollView.delegate === self) else { return }
        cancelForwarding()
        originalDelegate = scrollView.delegate
        self.forwardToDelegate = forwardToDelegate
        self.scrollView = scrollView
        scrollView.delegate = self
        scrollViewObservation = scrollView.observe(\.delegate) { [weak self] scrollView, _ in
            guard !(scrollView.delegate === self) else { return }
            if let proxy = scrollView.delegate as? UIScrollViewDelegateProxy {
                proxy.originalDelegate = self?.originalDelegate
                self?.cancelForwarding(restoresDelegate: false)
            } else {
                self?.originalDelegate = scrollView.delegate
                self?.scrollView = scrollView
                scrollView.delegate = self
            }
        }
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        forwardToDelegate?.scrollViewDidScroll?(scrollView)
        originalDelegate?.scrollViewDidScroll?(scrollView)
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>)
    {
        forwardToDelegate?.scrollViewWillEndDragging?(scrollView,
                                                      withVelocity: velocity,
                                                      targetContentOffset: targetContentOffset)
        originalDelegate?.scrollViewWillEndDragging?(scrollView,
                                                     withVelocity: velocity,
                                                     targetContentOffset: targetContentOffset)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        forwardToDelegate?.scrollViewWillBeginDragging?(scrollView)
        originalDelegate?.scrollViewWillBeginDragging?(scrollView)
    }

    private func cancelForwarding(restoresDelegate: Bool) {
        scrollViewObservation?.invalidate()
        guard restoresDelegate else { return }
        scrollView?.delegate = originalDelegate
    }
}
