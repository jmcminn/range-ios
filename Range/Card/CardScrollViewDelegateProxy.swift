import UIKit

protocol CardScrollViewDelegate: AnyObject {
    func cardScrollViewWillBeginDragging(_ scrollView: UIScrollView)
    func cardScrollViewDidScroll(_ scrollView: UIScrollView)
    func cardScrollView(_ scrollView: UIScrollView,
                        willEndDraggingwithVelocity velocity: CGPoint,
                        targetContentOffset: UnsafeMutablePointer<CGPoint>)
}


/**
 CardPresentationController needs to intercept the scroll view events from the scrollView in the card.
 This class replaces the original delegate on a provided UIScrollView and dispatches the calls to both, the original and the CardScrollViewDelegate.
 */
class CardScrollViewDelegateProxy: NSObject, UIScrollViewDelegate {
    
    private var scrollViewObservation: NSKeyValueObservation?
    private weak var originalDelegate: UIScrollViewDelegate?
    private weak var scrollView: UIScrollView?
    private weak var delegate: CardScrollViewDelegate?
    
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
    
    func forward(to delegate: CardScrollViewDelegate, delegateInvocationsFrom scrollView: UIScrollView) {
        guard !(scrollView.delegate === self) else { return }
        cancelForwarding()
        self.delegate = delegate
        self.originalDelegate = scrollView.delegate
        self.scrollView = scrollView
        scrollView.delegate = self
        scrollViewObservation = scrollView.observe(\.delegate) { [weak self] (scrollView, delegate) in
            guard !(scrollView.delegate === self) else { return }
            if let proxy = scrollView.delegate as? CardScrollViewDelegateProxy {
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
        delegate?.cardScrollViewDidScroll(scrollView)
        originalDelegate?.scrollViewDidScroll?(scrollView)
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        delegate?.cardScrollView(
            scrollView,
            willEndDraggingwithVelocity: CGPoint(x: -1000*velocity.x, y: -1000*velocity.y),
            targetContentOffset: targetContentOffset
        )
        originalDelegate?.scrollViewWillEndDragging?(
            scrollView,
            withVelocity: velocity,
            targetContentOffset: targetContentOffset
        )
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        delegate?.cardScrollViewWillBeginDragging(scrollView)
        originalDelegate?.scrollViewWillBeginDragging?(scrollView)
    }
    
    private func cancelForwarding(restoresDelegate: Bool) {
        scrollViewObservation?.invalidate()
        guard restoresDelegate else { return }
        scrollView?.delegate = originalDelegate
    }
}
