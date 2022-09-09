import UIKit

/// Delegate for `HeaderExpander` to receive notifications about state updates
protocol HeaderExpanderDelegate: AnyObject {
    /// Notifies that the gesture for header expansion is ending and the header expander will end expanding with given velocity
    /// This event will be followed by `headerExpanderDidUpdateState`
    func headerExpanderWillEndExpanding(_: HeaderExpander, withVelocity: CGFloat)
    /// notifies that the expander updated the headers state and whether it should be applied in the animated manner
    /// Invoked with the new state and the animation duration (0 = not animated)
    func headerExpanderDidUpdateState(_: HeaderExpander, animationDuration: TimeInterval)
}

/// HeaderExpander controls the height of 1..n headers based on user interactions with the driving scroll views
/// The layout is assumed to be:
///     - header 1
///     - header 2
///     - header ...
///     - scrollView
///
/// The expander keeps the internal state of calculated header heights and invokes the callback provided at init for the actual header
/// updates in the UI.
///
/// The expander expands the headers from n to 1, so from the most bottom one to the top one, or looking at it from the different
/// perspective, it collapses the headers from 1 to n, so from the top to bottom
///
/// User can only scroll the content if the headers are collapsed. And similarly, user can only expand headers if the scroll view is at the top
/// So the expander works by deciding whether the gesture should drag or not based on the current scroll view offset and headers state -
/// see `shouldDragHeaders` function.
///
/// For screens with a header and multiple driving scroll views (that user can switch between) use multiple HeaderExpanders
/// and activate/deactivate them as user is switching the scroll view
class HeaderExpander: NSObject {
    // configuration
    /// The minimum duration defines the minimum translation duration to expect.
    static let minimumDragExpectedDuration = 0.1

    /// unowned references to content view and scroll view
    private unowned let scrollView: UIScrollView
    private unowned let contentView: UIView

    /// the delegate for state updates
    weak var delegate: HeaderExpanderDelegate?

    /// last translation (y gesture position) when dragging
    private var scrollViewTranslation: CGFloat = 0.0
    /// change in header height from the beginning of the pan (from the `gestureInitialHeadersState`
    private var headerTranslation: CGFloat = 0.0
    private var lastContentOffsetWhileScrolling = CGPoint.zero
    /// The default value for animation duration for header expand/collapse when it's not calculated based on scroll velocity.
    private let animationDuration = 0.2

    /// header metrics with which it was activated, force unwrapped as it's only used after activation
    private var inputMetrics: HeadersInputMetrics!
    /// Calculator for current input metrics. Force unwrapped as it's only used after the expander was activated
    private var calculator: HeaderExpanderCalculator!

    /// updated by the expander
    private(set) var headersState: HeadersState!

    /// the state at the time when scroll view began dragging
    private var gestureInitialHeadersState: HeadersState!

    /// handles for observing scroll view properties
    private var observations = [NSKeyValueObservation]()

    /// - Parameters
    ///     - scrollView:   the scroll view that drives the interaction
    ///     - contentView:     the view that contains the headers and the scroll view. It is assumed that headers and scroll take the
    ///     whole height of the contentView
    init(drivingScrollView scrollView: UIScrollView, contentView: UIView) {
        self.scrollView = scrollView
        self.contentView = contentView
    }

    /// By default it is assumed that headers and scroll view take the whole height of the contentView, but this may be adjusted using
    /// this parameter
    var bottomContentEdgeInset: CGFloat = 0.0 {
        didSet {
            updateContentInset()
        }
    }

    /// Start tracking the scroll view changes
    /// - Parameters:
    ///     - headersInputMetrics: metrics defining the header(s) sizes
    func activate(headersInputMetrics: [HeaderInputMetrics]) {
        inputMetrics = HeadersInputMetrics(headersInputMetrics)
        calculator = HeaderExpanderCalculator(inputMetrics: inputMetrics)
        headersState = calculator.headersState(forTotalHeight: inputMetrics.totalInitialHeadersHeight)
        updateContentInset()

        // make the scrollView gesture recognizer recognize on the whole view - so panning cover headers too
        contentView.addGestureRecognizer(scrollView.panGestureRecognizer)

        // If content offset is non zero but the headers are not collapsed then reset to zero,
        // as the offset might be != zero only for collapsed headers
        // (the headers may have changed while being controlled by another expander and this one
        // was inactive)
        if !headersState.allCollapsed, scrollView.contentOffset.y != 0 {
            scrollView.setContentOffset(.zero, animated: false)
        }
        setupScrollViewObservers()
        setupScrollViewDelegate()
    }

    /// Deactivate the header expander.
    /// It removes the scroll pan gesture recognizer from the viewToPan and stops updating the header(s) height(s) on scroll view changes
    func deactivate() {
        contentView.removeGestureRecognizer(scrollView.panGestureRecognizer)
        scrollView.addGestureRecognizer(scrollView.panGestureRecognizer)
        removeScrollViewObservers()
        removeScrollViewDelegate()
    }

    /// Observe the scroll view properties
    private func setupScrollViewObservers() {
        observations.append(scrollView.observe(\.contentSize) { [weak self] _, _ in
            self?.updateContentInset()
        })
        observations.append(scrollView.observe(\.frame) { [weak self] _, _ in
            self?.updateContentInset()
        })
    }

    private func removeScrollViewObservers() {
        observations.forEach { $0.invalidate() }
        observations.removeAll()
    }

    /// In addition to observes the header expander needs the scroll view delegate notifications to handle animating headers
    /// to their collapsed/expanded states on gesture end
    private func setupScrollViewDelegate() {
        scrollView.forwardDelegateInvocations(to: self)
    }

    private func removeScrollViewDelegate() {
        scrollView.cancelForwardingDelegateInvocations(to: self)
    }

    /// Updates the content inset so the headers can collapse (adds some bottom inset if the content is too short)
    private func updateContentInset() {
        let contentOffset = scrollView.contentOffset
        // bottom inset is what is missing for scrollview content with collapsed headers to
        // occupy the whole height (minus the bottomContentEdgeInset that may be optionally added
        // below the scroll view
        let bottomInset = max(
            0,
            contentView.frame.height - inputMetrics.totalCollapsedHeadersHeight
                - scrollView.contentSize.height - bottomContentEdgeInset
        )
        scrollView.contentInset.bottom = bottomInset
        scrollView.contentOffset = contentOffset
    }

    /// Since the headers are always collapsed from first to last and expanded from last to first
    /// setting first expanded header can be used to expand all headers with number >= headerNumber.
    /// To collapse all invoke with `headerNumber` = headers.count
    func setFirstExpandedHeader(_ headerNumber: Int, animated _: Bool) {
        headersState = calculator.headersState(forFirstExpandedHeader: headerNumber)
        delegate?.headerExpanderDidUpdateState(self, animationDuration: animationDuration)
    }
}

// MARK: - scroll view delegate

extension HeaderExpander: UIScrollViewDelegate {
    /// Save the state at the beginning of the drag gesture
    func scrollViewWillBeginDragging(_: UIScrollView) {
        gestureInitialHeadersState = headersState

        if shouldDragHeaders() {
            scrollView.showsVerticalScrollIndicator = false
        } else {
            scrollView.showsVerticalScrollIndicator = true
        }
    }

    /// handle scroll by either dragging (in which case the contentOffset is manually set on scrollView to prevent scrolling)
    /// or letting it scroll
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let previousTranslation = scrollViewTranslation
        scrollViewTranslation = scrollView.panGestureRecognizer.translation(in: scrollView).y
        if shouldDragHeaders() {
            headerTranslation += scrollViewTranslation - previousTranslation
            let offset = adjustedContentOffset()
            lastContentOffsetWhileScrolling = offset
            scrollView.contentOffset = offset // Warning : calls `scrollViewDidScroll(_:)` again
            let height = gestureInitialHeadersState.totalHeight + headerTranslation
            dragHeaders(toHeight: height)
        } else {
            lastContentOffsetWhileScrolling = scrollView.contentOffset
        }
    }

    /// Hack: When dragging we ignore the offset changes in scroll view (override them) but if the user pans really fast and is quite close
    /// to the top of the content, we can get the `scrollViewDidScroll` already when it should drag and ignore the offset change
    /// to 0, fix it here.
    func adjustedContentOffset() -> CGPoint {
        var contentOffset = lastContentOffsetWhileScrolling
        let topInset = -scrollView.contentInset.top
        // Between two `scrollViewDidScroll:` calls,
        // the scrollView exceeds the top's contentInset. We adjust the target.
        if (contentOffset.y - topInset) * (scrollView.contentOffset.y - topInset) < 0 {
            contentOffset.y = topInset
        }
        return contentOffset
    }

    /// Whether the headers should be dragged or the scrolling should be allowed
    func shouldDragHeaders() -> Bool {
        if !scrollView.isTracking {
            return false
        }
        // if headers are not collapsed then it drags (= it scrolls only when headers are collapsed)
        if !headersState.allCollapsed {
            return true
        }
        // if headers are collapsed but we're scrolling down and already at the top of the
        // content then drag too
        if scrollView.isContentOriginInBounds, !scrollView.scrollsUp {
            return true
        }
        // otherwise allow scrolling
        return false
    }

    /// sets `headersState` based on height. Applies rubberBand effect if the height is too big and clamps to min collapsed height.
    func dragHeaders(toHeight height: CGFloat) {
        var height = height
        if height > inputMetrics.totalExpandedHeadersHeight {
            height = inputMetrics
                .totalExpandedHeadersHeight * (1 + log10(height / inputMetrics.totalExpandedHeadersHeight))
        }
        height = max(inputMetrics.totalCollapsedHeadersHeight, height)
        headersState = calculator.headersState(forTotalHeight: height)
        delegate?.headerExpanderDidUpdateState(self, animationDuration: 0.0)
    }

    /// Calculate the target heades state based on the state when interaction started, current state and velocity
    ///
    /// 1. if first header is overexpanded just bring it to expanded no matter what is the velocity
    /// 2. for low velocity the target state doesn't use velocity at all and rather checks if expansion passed a 30% mark towards new state
    /// 3. for higher velocity it's being used to calculate a target header but in a way that don't expands/collapses more than 1 header
    ///     it will not expand/collapse any header if it isn't partially expanded currently as the assumption is that user has to initiate the
    ///     expansion/collapse
    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        headerTranslation = 0
        scrollViewTranslation = 0
        // We reset the translation each time the user ends dragging.
        // Otherwise the calculation is wrong in `scrollViewDidScroll(_:)`
        // if the user drags while the animation did not finish.
        scrollView.panGestureRecognizer.setTranslation(.zero, in: nil)

        let velocity = -1000 * velocity.y
        delegate?.headerExpanderWillEndExpanding(self, withVelocity: velocity)

        // if should drag then calculate the target headers state (so they're only in collapsed/
        // expanded state) and reset the targetContentOffset so there scroll view doesn't scroll
        if shouldDragHeaders() {
            if let targetHeadersState = calculator.targetHeadersState(
                forInitialState: gestureInitialHeadersState,
                currentState: headersState,
                velocity: velocity
            ) {
                // calculate animation duration based on velocity and target content offset but
                // use some minimal value (velocity might be very high, etc)
                let animationDuration: TimeInterval = max(
                    animationDuration,
                    velocity != 0.0
                        ? abs((scrollView.contentOffset.y - targetContentOffset.pointee.y) / velocity)
                        : 0.0
                )
                headersState = targetHeadersState
                delegate?.headerExpanderDidUpdateState(self, animationDuration: animationDuration)
            }
            // if we drag headers we don't want the content offset change
            targetContentOffset.pointee.y = lastContentOffsetWhileScrolling.y
        }
    }
}
