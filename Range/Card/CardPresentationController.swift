import UIKit

// This implementation is based on https://github.com/applidium/ADOverlayContainer and https://github.com/babylonhealth/DrawerKit

/**
 A custom UIPresentationController to present view controllers in a way similar to Apple [sheets](https://developer.apple.com/design/human-interface-guidelines/ios/views/sheets/)
 
 It adds a pan gesture recognizer to the presented view to allow for dragging the card up/down.
 
 It supports 3 predefined card positions to which the presented card snaps - see ``CardPresentable`` and ``CardPosition`` for more details
 
 It also registers itself as a delegate for ``CardPresentable/drivingScrollView()-2kjov``.
 So if the presented card contains a scroll view, it's behavior will change so it only scrolls vertically if the card is at its full height, otherwise it'll drag the card.
 */
class CardPresentationController: UIPresentationController {
    
    let cardConfig: CardConfiguration
    let topDown = false
    var position: CardPosition
    
    var presentationContainerView: PresentationContainerView!
    var blurView: UIView?
    var sliderView: UIView?
    var dragGestureRecognizer: UIPanGestureRecognizer?
    var scrollViewDelegateProxy: CardScrollViewDelegateProxy?
    var scrollViewTranslation: CGFloat = 0.0
    var drawerTranslation: CGFloat = 0.0
    var lastContentOffsetWhileScrolling = CGPoint.zero
    
    
    // configuration
    /// The minimum velocity to reach to move forward. The default value is 400 pt/s.
    static let minimumDragVelocityToChangeCardPosition = 400.0
    /// The minimum duration defines the minimum translation duration to expect.
    static let minimumDragExpectedDuration = 0.1
    
    
    init(presentedViewController: (UIViewController & CardPresentable),
         presenting presentingViewController: UIViewController?, cardConfig: CardConfiguration) {
        self.cardConfig = cardConfig
        self.position = cardConfig.initialCardPosition
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }
    
    override func presentationTransitionWillBegin() {
        setupPresentationContainerView()
        presentedViewController.loadViewIfNeeded()
        setupCardDragRecogniser()
        setupScrollViewDelegate()
        setupSafeAreaBlur()
        setupSliderView()
    }
    
    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
    
    override func dismissalTransitionDidEnd(_ completed: Bool) {
        removePresentationContainerView()
        removeCardDragRecogniser()
        removeScrollViewDelegate()
        removeSafeAreaBlur()
        removeSliderView()
    }
    
    private func cardHeight(forPosition cardPosition: CardPosition) -> CGFloat {
        var height = (presentedViewController as? CardPresentable)?.height(
            forWidth: containerViewSize.width,
            cardPosition: cardPosition
        ) ?? 0.0
        // add the bottom safearea insets when presented from bottom (but only if position support, so if height >= 0)
        if !topDown && height >= 0 {
            height += containerView?.safeAreaInsets.bottom ?? 0.0
        }
        return min(height, maxAllowedCardHeight)
    }
    
    override var frameOfPresentedViewInContainerView: CGRect {
        let targetHeight = cardHeight(forPosition: position)
        var frame = containerViewBounds
        frame.origin.y = frame.size.height - targetHeight
        frame.size.height = maxAllowedCardHeight
        return frame
    }
    
    /**
     The default containerView accepts all user interaction and doesn't let the view from presentingViewController respond.
     This method replaces it with a view that will pass the touches through to touchDelegate which in turn will direct them to the presenting view.
     This way user can interact with the original view while the card view is presented on the screen.
     */
    func setupPresentationContainerView() {
        guard self.presentationContainerView == nil else { return }
        
        let presentationContainerView = PresentationContainerView()
        presentationContainerView.touchDelegate = self
        presentationContainerView.backgroundColor = .clear
        presentationContainerView.frame = containerView?.superview?.frame ?? .zero
        presentationContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        if let containerView = containerView {
            containerView.superview?.addSubview(presentationContainerView)
            presentationContainerView.addSubview(containerView)
        }
        
        self.presentationContainerView = presentationContainerView
    }
    
    func removePresentationContainerView() {
        // the containerView is removed by UIKit when dismissal ends
        // so it's not necessary to restore it in its original superview
        presentationContainerView.removeFromSuperview()
    }
    
}

/// Properties
extension CardPresentationController {
    var containerViewBounds: CGRect {
        containerView?.bounds ?? .zero
    }
    var containerViewSize: CGSize {
        containerViewBounds.size
    }
    // we don't want to cover the top safe area
    var maxAllowedCardHeight: CGFloat {
        containerViewBounds.height - (containerView?.safeAreaInsets.top ?? 0.0)
    }
    var cardHeight: CGFloat {
        get {
            guard let presentedView = presentedView else { return 0.0 }
            return containerViewSize.height - presentedView.frame.origin.y
        }
        set {
            guard let presentedView = presentedView else { return }
            presentedView.frame.origin.y = containerViewSize.height - newValue
        }
    }
    // did card reach any position?
    var cardHasReachedAPosition: Bool {
        let height = cardHeight
        return height == cardHeight(forPosition: .min) || height == cardHeight(forPosition: .medium) || height == cardHeight(forPosition: .max)
    }
    
}

/// Card drag handling
extension CardPresentationController {
    func setupCardDragRecogniser() {
        guard dragGestureRecognizer == nil else { return }
        let panGesture = UIPanGestureRecognizer(target: self,
                                                action: #selector(handleCardDrag))
        presentedView?.addGestureRecognizer(panGesture)
        dragGestureRecognizer = panGesture
    }
    
    func removeCardDragRecogniser() {
        guard let panGesture = dragGestureRecognizer else { return }
        presentedView?.removeGestureRecognizer(panGesture)
        dragGestureRecognizer = nil
    }
    
    @objc func handleCardDrag() {
        guard let panGesture = dragGestureRecognizer, let view = panGesture.view else { return }
        
        switch panGesture.state {
        case .began:
            fallthrough
            
        case .changed:
            (presentedViewController as? CardPresentable)?.drivingScrollView()?.showsVerticalScrollIndicator = false
            let translation = panGesture.translation(in: view)
            let height = cardHeight(forPosition: position) + (topDown ? translation.y : -translation.y)
            self.drag(toHeight: height, applyRubberBand: true)
        case .ended:
            fallthrough
        case .failed:
            fallthrough
        case .cancelled:
            let velocity = panGesture.velocity(in: view).y
            let targetPosition = targetPosition(withVelocity: velocity)
            setPosition(targetPosition, withVelocity: velocity, animated: true)
        default:
            break
        }
    }
    
    /***
     * sets height based on height parameter and rubberBand enabled/disabled. If rubberBand is disabled it just clamps the height
     * between min and max (taken from CardPresentable). If rubberBand is enabled it allows for height below
     * min and above max, but applies a transformation that adds a rubber band effect
     */
    func drag(toHeight height: CGFloat, applyRubberBand rubberBand: Bool) {
        let minHeight = cardHeight(forPosition: .min)
        let maxHeight = cardHeight(forPosition: .max)
        var height = height
        
        if (rubberBand) {
            if height > maxHeight {
                height = maxHeight * (1 + log10(height / maxHeight))
            } else if height < minHeight {
                height = minHeight * (1 - log10(2 - height / minHeight))
            }
        } else {
            height = max(minHeight, min(maxHeight, height))
        }
        cardHeight = height
    }
    
    /**
     * Calculates target position based on current height and velocity. (if panned fast might go from max straight to min)
     */
    func targetPosition(withVelocity velocity: CGFloat) -> CardPosition {
        let currentHeight = cardHeight
        let targetHeight = currentHeight + CardPresentationController.minimumDragExpectedDuration * (topDown ? 1 : -1) * velocity
        
        let heightsForPositions: [CardPosition:CGFloat] = [
            .min: cardHeight(forPosition: .min),
            .medium: cardHeight(forPosition: .medium),
            .max: cardHeight(forPosition: .max),
        ]
        let availablePositions: [CardPosition] = heightsForPositions[.medium]! < 0 ? [.min, .max] : [.min, .medium, .max]
        let closestPositions: [CardPosition] = availablePositions.sorted {
            let height0 = heightsForPositions[$0]!
            let distance0 = abs(targetHeight - height0)
            let height1 = heightsForPositions[$1]!
            let distance1 = abs(targetHeight - height1)
            if distance0 == distance1 {
                return height0 < height1
            } else {
                return distance0 < distance1
            }
        }
        if abs(velocity) > CardPresentationController.minimumDragVelocityToChangeCardPosition {
            let takeMax = topDown ? velocity > 0 : velocity < 0
            let firstPositionBigger = closestPositions[0].rawValue > closestPositions[1].rawValue
            if takeMax {
                return firstPositionBigger ? closestPositions[0] : closestPositions[1]
            } else {
                return firstPositionBigger ? closestPositions[1] : closestPositions[0]
            }
        } else {
            return closestPositions[0];
        }
    }
    
}

/// Scroll view handling
extension CardPresentationController: CardScrollViewDelegate {
    enum CardTranslationPosition {
        case top
        case bottom
        case inFlight
        case stationary
    }
    
    func setupScrollViewDelegate() {
        guard let drivingScrollView = (presentedViewController as? CardPresentable)?.drivingScrollView() else { return }
        let delegateProxy = CardScrollViewDelegateProxy()
        delegateProxy.forward(to: self, delegateInvocationsFrom: drivingScrollView)
        scrollViewDelegateProxy = delegateProxy
    }
    
    func removeScrollViewDelegate() {
        if let delegateProxy = scrollViewDelegateProxy {
            delegateProxy.cancelForwarding()
        }
    }
    
    func cardScrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if shouldDrag(scrollView) {
            scrollView.showsVerticalScrollIndicator = false
        } else {
            scrollView.showsVerticalScrollIndicator = true
        }
    }
    
    func cardScrollViewDidScroll(_ scrollView: UIScrollView) {
        let previousTranslation = scrollViewTranslation
        scrollViewTranslation = scrollView.panGestureRecognizer.translation(in: scrollView).y
        if shouldDrag(scrollView) {
            drawerTranslation += scrollViewTranslation - previousTranslation
            let offset = adjustedContentOffset(scrollView)
            lastContentOffsetWhileScrolling = offset
            scrollView.contentOffset = offset // Warning : calls `cardScrollViewDidScroll(_:)` again
            let height = cardHeight(forPosition: self.position) - drawerTranslation
            let scrollViewBottomContentInset = scrollView.adjustedContentInset.bottom
            self.drag(toHeight: height, applyRubberBand: scrollView.contentSize.height + scrollViewBottomContentInset <= scrollView.bounds.height)
        } else {
            lastContentOffsetWhileScrolling = scrollView.contentOffset
        }
    }
    
    func cardScrollView(_ scrollView: UIScrollView, willEndDraggingwithVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        drawerTranslation = 0
        scrollViewTranslation = 0
        // We reset the translation each time the user ends dragging.
        // Otherwise the calculation is wrong in `cardScrollViewDidScroll(_:)`
        // if the user drags the card while the animation did not finish.
        scrollView.panGestureRecognizer.setTranslation(.zero, in: nil)
        // We adjust the content offset and the velocity only if the card will be dragged.
        let translationPosition = translationPosition
        if translationPosition == .bottom && targetContentOffset.pointee.y > -scrollView.contentInset.top {
            // The user raises its finger in the bottom position
            // and the content offset will exceed the top content inset.
            targetContentOffset.pointee.y = -scrollView.contentInset.top
        } else if translationPosition == .inFlight && !cardHasReachedAPosition {
            targetContentOffset.pointee.y = lastContentOffsetWhileScrolling.y
        }
        // If the card is in flight and the user scrolls bottom, we ignore the velocity and we do not
        // modify the target offset.
        let adjustedVelocity = shouldDrag(scrollView) ? velocity.y : 0.0
        let targetPosition = targetPosition(withVelocity: adjustedVelocity)
        setPosition(targetPosition, withVelocity: velocity.y, animated: true)
    }
    
    func shouldDrag(_ scrollView: UIScrollView) -> Bool {
        if !scrollView.isTracking {
            return false
        }
        let scrollViewBottomContentInset = scrollView.adjustedContentInset.bottom
        if scrollView.contentSize.height + scrollViewBottomContentInset <= scrollView.bounds.height {
            return true
        }
        switch translationPosition {
        case .bottom:
            return !scrollView.isContentOriginInBounds && scrollView.scrollsUp
        case .top:
            return scrollView.isContentOriginInBounds && !scrollView.scrollsUp
        case .inFlight:
            return scrollView.isContentOriginInBounds || scrollView.scrollsUp
        case .stationary:
            return false
        }
    }
    
    var translationPosition: CardTranslationPosition {
        get {
            let height = cardHeight
            let minHeight = cardHeight(forPosition: .min)
            let maxHeight = cardHeight(forPosition: .max)
            let isAtTop = height == maxHeight
            let isAtBottom = height == minHeight
            if isAtTop && isAtBottom {
                return .stationary
            } else if isAtTop {
                return .top
            } else if isAtBottom {
                return .bottom
            } else {
                return .inFlight
            }
        }
    }
    func adjustedContentOffset(_ scrollView: UIScrollView) -> CGPoint {
        var contentOffset = lastContentOffsetWhileScrolling
        let topInset = -scrollView.contentInset.top
        let translationPosition = translationPosition
        if translationPosition == .inFlight || translationPosition == .top {
            // If the scroll's animation did not finish when the user translates the card,
            // the content offset may have exceeded the top inset. We adjust it.
            if contentOffset.y < topInset {
                contentOffset.y = topInset
            }
        }
        // Between two `cardScrollViewDidScroll:` calls,
        // the scrollView exceeds the top's contentInset. We adjust the target.
        if (contentOffset.y - topInset) * (scrollView.contentOffset.y - topInset) < 0 {
            contentOffset.y = topInset
        }
        return contentOffset
    }
}


/// Animation
extension CardPresentationController {
    func setPosition(_ position: CardPosition, withVelocity velocity: CGFloat, animated: Bool = false) {
        self.position = position
        var height = cardHeight(forPosition: position)
        if (position == .medium && height < 0) {
            // ignore medium, set to max
            self.position = .max
            height = cardHeight(forPosition: self.position)
        }
        (presentedViewController as? CardPresentable)?.cardWillChangePosition(self.position)
        if animated {
            let animator = animator(withVelocity: velocity)
            animator.addAnimations {
                self.cardHeight = height
            }
            animator.startAnimation()
        } else {
            cardHeight = height
        }
        (presentedViewController as? CardPresentable)?.cardDidChangePosition(self.position)
    }
    
    func animator(withVelocity velocity: CGFloat) -> UIViewPropertyAnimator {
        let defaultMass = 1.0
        let defaultDamping = 0.6
        let defaultResponse = 0.3
        let minDamping = 1.0
        let minVelocityConsideration = 150.0
        let maxVelocityConsideration = 3000.0
        let velocityRange = maxVelocityConsideration - minVelocityConsideration
        
        let velocity = min(maxVelocityConsideration, max(abs(velocity), minVelocityConsideration))
        let normalizedVelocity = (velocity - minVelocityConsideration) / velocityRange
        let normalizedDamping = normalizedVelocity * (defaultDamping - minDamping) + minDamping
        let stiffness = pow(2 * Double.pi / defaultResponse, 2)
        let damping = 4 * Double.pi * normalizedDamping / defaultResponse
        let timingParameters = UISpringTimingParameters(mass: defaultMass, stiffness: stiffness, damping: damping, initialVelocity: .zero)
        // duration is ignored when using `UISpringTimingParameters.init(mass:stiffness:damping:initialVelocity)`
        return UIViewPropertyAnimator(duration: 0, timingParameters: timingParameters)
    }
}

extension CardPresentationController: PresentationContainerViewDelegate {
    func view(_ view: PresentationContainerView, shouldPassthroughTouchAt point: CGPoint) -> Bool {
        guard let presentedView = presentedView else { return false }
        return !presentedView.bounds.contains(presentedView.convert(point, from: view))
    }
    
    func view(_ view: PresentationContainerView, forTouchAt point: CGPoint) -> UIView? {
        return presentingViewController.view
    }
}

/// Bluring
extension CardPresentationController {
    func setupSafeAreaBlur() {
        guard cardConfig.showSafeAreaBlur else { return }
        
        let blur = UIBlurEffect(style: .regular)
        let blurView = UIVisualEffectView(effect: blur)
        presentationContainerView.addSubview(blurView)
        blurView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(presentationContainerView.safeAreaInsets.bottom)
        }
        self.blurView = blurView
    }
    
    func removeSafeAreaBlur() {
        if let blurView = blurView {
            blurView.removeFromSuperview()
        }
    }
}

/// Slider
extension CardPresentationController {
    func setupSliderView() {
        guard cardConfig.showSliderView else { return }
        
        let sliderView = UIView()
        sliderView.backgroundColor = Colors.Neutral_06
        sliderView.layer.cornerRadius = 2.5
        presentedView?.addSubview(sliderView)
        sliderView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(33)
            make.height.equalTo(5)
            make.top.equalTo(8)
        }
        self.sliderView = sliderView
    }
    func removeSliderView() {
        if let sliderView = sliderView {
            sliderView.removeFromSuperview()
        }
    }
}

