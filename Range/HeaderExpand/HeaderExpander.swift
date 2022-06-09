import UIKit

// TODO: expand early - not supported for now
// It would require changes in the shouldDragHeaders - so it drags even if not at the top of scroll
/// Configuration of expandable header. Currently it's only an enum with expanding behavior
// enum HeaderExpandingBehavior {
//    // expand as soon as user scrolls down (no matter what's the current scroll offset)
//    case expandEarly
//    // expand when user scrolls down but only after the scroll view content reached
//    // it's minimal value (so the scroll shows the top of the content):
//    case expandLate
// }

/// Struct used for activating the `HeaderExpander`. Describes the metrics for one header
struct HeaderInputMetrics {
    var initialHeight: CGFloat // initial header height when activating the expander
    var collapsedHeight: CGFloat // minimal allowed height in the collapsed form
    var expandedHeight: CGFloat // maximal height in the expanded form (although the 1st header
    // might get over expanded)
}

/// Possible header expansion values
enum HeaderExpansion {
    case collapsed // has its collapsed height
    case partiallyExpanded // has the height between collapsed and expanded
    case expanded // has its expanded height
    case overExpanded // has height higher than the expanded height
}

/// Possible state for the header.
struct HeaderState {
    var height: CGFloat // current height
    var expansion: HeaderExpansion // expansion state based on the height and input metrics
}

struct HeadersState {
    let headersStates: [HeaderState]
    let totalHeight: CGFloat
    lazy var allCollapsed: Bool = headersStates.allSatisfy { $0.expansion == .collapsed }
    lazy var heights: [CGFloat] = headersStates.map(\.height)
}

// TODO: 51 headers:
// - implement switching
// - handle expand early (LATER)

// Dragging:
/// header 1
/// header 2
/// scroll View
///
/// header n can drag up/down headers [1...n]
///
/// scroll view drags everything
/// header can be configured to expand:
/// a) on offset 0 (once the scroll scrolled to the top)
///   XOR
/// b) expand early (on drag down)
/// scroll view collapses headers 1 -> n
/// expands n -> 1

/// Docs:
///
/// For screens with a header but multiple driving scroll views (that user can switch between) use multiple HeaderExpanders
/// and activate/deactivate them as user is switching the scroll view
class HeaderExpander: NSObject {
    // configuration
    /// The minimum velocity to reach to move forward. The default value is 400 pt/s.
//    static let minimumDragVelocityToChangePosition = 400.0
    /// The minimum duration defines the minimum translation duration to expect.
    static let minimumDragExpectedDuration = 0.1

    private unowned let scrollView: UIScrollView
    private unowned let viewToPan: UIView
//    private let configuration: [HeaderExpandingBehavior]
    private let headersHeightsUpdateCallback: ([CGFloat], TimeInterval) -> Void

    /// last translation (y gesture position) when dragging
    private var scrollViewTranslation: CGFloat = 0.0
    /// change in header height from the beginning of the pan (from the `gestureInitialHeadersState`
    private var headerTranslation: CGFloat = 0.0
    private var lastContentOffsetWhileScrolling = CGPoint.zero
    /// The default value for animation duration for header expand/collapse when it's not calculated based on scroll velocity.
    private let animationDuration = 0.2

    /// header metrics with which it was activated, force unwrapped as it's only used after activation
    private var headersInputMetrics: [HeaderInputMetrics]! {
        didSet {
            totalInitialHeadersHeight = headersInputMetrics.map(\.initialHeight).reduce(0.0, +)
            totalCollapsedHeadersHeight = headersInputMetrics.map(\.collapsedHeight).reduce(0.0, +)
            totalExpandedHeadersHeight = headersInputMetrics.map(\.expandedHeight).reduce(0.0, +)
        }
    }

    /// updated by the expander
    private var headersState: HeadersState!

    /// the state at the time when scroll view began dragging
    private var gestureInitialHeadersState: HeadersState!

    /// required for calculaction, precomputed when setting `headersMetrics`
    private var totalInitialHeadersHeight: CGFloat = 0
    private var totalCollapsedHeadersHeight: CGFloat = 0
    private var totalExpandedHeadersHeight: CGFloat = 0

    /// handles for observing scroll view properties
    private var observations = [NSKeyValueObservation]()
    /// to become a drivingScrollView delegate
    private var scrollViewDelegateProxy: UIScrollViewDelegateProxy?

    /// by default it's nil, so there's not limit enforced but may be limited during scroll view deceleration to disallow
    /// header expansion
    private var maxAllowedTotalHeadersHeight: CGFloat?

    ///
    init(
        drivingScrollView scrollView: UIScrollView,
        viewToPan: UIView,
//        configuration: [HeaderExpandingBehavior],
        headersHeightsUpdateCallback: @escaping ([CGFloat], TimeInterval) -> Void
    ) {
        self.scrollView = scrollView
        self.viewToPan = viewToPan
//        self.configuration = configuration
        self.headersHeightsUpdateCallback = headersHeightsUpdateCallback
    }

    /// First activation sets the scroll view content offset to match the current headers state.
    /// Subsequent activations preserve the content offset if possible (the headers may have changed their heights in the meantime, so
    /// it may still be necessary to adjust the offset)
    func activate(headersInputMetrics: [HeaderInputMetrics]) {
        self.headersInputMetrics = headersInputMetrics
        // make the scrollView gesture recognizer recognize on the whole view - so panning cover headers too
        viewToPan.addGestureRecognizer(scrollView.panGestureRecognizer)

        setupScrollViewObservers()
        setupScrollViewDelegate()

        headersState = headersState(forTotalHeight: totalInitialHeadersHeight)
    }

    /// Deactivate the header expander.
    /// It removes the scroll pan gesture recognizer from the viewToPan and stops updating the header(s) height(s) on scroll view changes
    func deactivate() {
        viewToPan.removeGestureRecognizer(scrollView.panGestureRecognizer)
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

    /// In addition to observes the header expander needs the scroll view delegate notifications to handle animating headers to their collapsed/expanded
    /// states on gesture end
    private func setupScrollViewDelegate() {
        let delegateProxy = UIScrollViewDelegateProxy()
        delegateProxy.forward(to: self, delegateInvocationsFrom: scrollView)
        scrollViewDelegateProxy = delegateProxy
    }

    private func removeScrollViewDelegate() {
        scrollViewDelegateProxy?.cancelForwarding()
    }

    /// Updates the content inset so the headers can collapse (adds some bottom inset if the content is too short)
    private func updateContentInset() {
        let contentOffset = scrollView.contentOffset
        // optionally limit the inset when max allowed total headers height is set, so the content
        // bounces early (and not reveals the expanded headers)
        let bottomInset = max(0, scrollView.frame.height - totalCollapsedHeadersHeight - scrollView.contentSize.height)
        scrollView.contentInset.bottom = bottomInset
        scrollView.contentOffset = contentOffset
    }

    /// Since the headers are always collapsed from first to last and expanded from last to first
    /// setting first expanded header can be used to expand all headers with number >= headerNumber.
    /// To collapse all invoke with `headerNumber` = headers.count
    func setFirstExpandedHeader(_ headerNumber: Int, animated _: Bool) {
        headersState = headersState(forFirstExpandedHeader: headerNumber)
        headersHeightsUpdateCallback(headersState.heights, animationDuration)
    }
}

// MARK: - scroll view delegate

extension HeaderExpander: UIScrollViewDelegate {
    /// Save the state at the beginning of the drag gesture
    func scrollViewWillBeginDragging(_: UIScrollView) {
        gestureInitialHeadersState = headersState
    }

    /// handle scroll by either dragging (in which case the contentOffset is manually set on scrollView to prevent scrolling)
    /// or letting it scroll
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let previousTranslation = scrollViewTranslation
        scrollViewTranslation = scrollView.panGestureRecognizer.translation(in: scrollView).y
        if shouldDragHeaders(scrollView) {
            headerTranslation += scrollViewTranslation - previousTranslation
            let offset = adjustedContentOffset(scrollView)
            lastContentOffsetWhileScrolling = offset
            scrollView.contentOffset = offset // Warning : calls `scrollViewDidScroll(_:)` again
            let height = gestureInitialHeadersState.totalHeight + headerTranslation
            dragHeaders(toHeight: height)
        } else {
            lastContentOffsetWhileScrolling = scrollView.contentOffset
        }
    }

    func adjustedContentOffset(_: UIScrollView) -> CGPoint {
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
    func shouldDragHeaders(_ scrollView: UIScrollView) -> Bool {
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
        if height > totalExpandedHeadersHeight {
            height = totalExpandedHeadersHeight * (1 + log10(height / totalExpandedHeadersHeight))
        }
        height = max(totalCollapsedHeadersHeight, height)
        headersState = headersState(forTotalHeight: height)
        headersHeightsUpdateCallback(headersState.heights, 0.0)
    }

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

        if shouldDragHeaders(scrollView) {
            let velocity = -1000 * velocity.y
            if let targetHeadersState = targetHeadersState(withVelocity: velocity) {
                // calculate animation duration based on velocity and target content offset but
                // use some minimal value (velocity might be very high, etc)
                let animationDuration: TimeInterval = max(
                    animationDuration,
                    velocity != 0.0
                        ? abs((scrollView.contentOffset.y - targetContentOffset.pointee.y) / velocity)
                        : 0.0
                )
                headersState = targetHeadersState
                headersHeightsUpdateCallback(headersState.heights, animationDuration)
            }
            // if we drag headers we don't want the content offset change
            targetContentOffset.pointee.y = lastContentOffsetWhileScrolling.y
        }
    }
}

// MARK: - state calculationss

extension HeaderExpander {
    /// calculate header states for given total height
    private func headersState(forTotalHeight totalHeight: CGFloat) -> HeadersState {
        // output heights
        var heights = headersInputMetrics.map(\.collapsedHeight)
        // the height to be spread over n=>1 headers on top of their collapsed heights
        var heightToSpreadOverHeaders = totalHeight - totalCollapsedHeadersHeight
        var currentHeader = headersInputMetrics.count - 1
        while currentHeader > 0, heightToSpreadOverHeaders > 0 {
            // do not add more than the diff between expanded and collapsed
            let heightToAdd = min(
                heightToSpreadOverHeaders,
                headersInputMetrics[currentHeader].expandedHeight - headersInputMetrics[currentHeader]
                    .collapsedHeight
            )
            heights[currentHeader] += heightToAdd
            heightToSpreadOverHeaders -= heightToAdd
            currentHeader -= 1
        }
        // header 0 gets all the remaining height
        heights[0] += heightToSpreadOverHeaders
        return headersState(forHeights: heights)
    }

    /// Converts heights to states with appropriate expansion states based on the heights
    private func headersState(forHeights heights: [CGFloat]) -> HeadersState {
        let headersStates: [HeaderState] = zip(headersInputMetrics, heights)
            .map { inputMetrics, height in
                let expansion: HeaderExpansion
                if height > inputMetrics.expandedHeight {
                    expansion = .overExpanded
                } else if height == inputMetrics.expandedHeight {
                    expansion = .expanded
                } else if height > inputMetrics.collapsedHeight {
                    expansion = .partiallyExpanded
                } else {
                    expansion = .collapsed
                }
                return HeaderState(height: height, expansion: expansion)
            }
        let totalHeight = headersStates.map(\.height).reduce(0.0, +)
        return HeadersState(headersStates: headersStates, totalHeight: totalHeight)
    }

    /// Calculates target headers state based on the current state (total height) and velocity
    /// - Returns: HeadersState if state needs to change, otherwise `nil`
    func targetHeadersState(withVelocity velocity: CGFloat) -> HeadersState? {
        // if the first header is overexpanded just make it expanded
        if headersState.headersStates.first?.expansion == .overExpanded {
            return headersState(forTotalHeight: totalExpandedHeadersHeight)
        }

        // possibly expand or collapse a header if it's partially expanded
        // (there can only be 1 header in this state)
        if let firstPartiallyExpandedIndex = headersState.headersStates
            .firstIndex(where: { $0.expansion == .partiallyExpanded })
        {
            let metrics = headersInputMetrics[firstPartiallyExpandedIndex]
            let initialState = gestureInitialHeadersState.headersStates[firstPartiallyExpandedIndex]
            let currentState = headersState.headersStates[firstPartiallyExpandedIndex]
            // low velocity
            if abs(velocity) < 150 {
                // for low velocity prefer changing state from the previous one (before gesture
                // started) if travelled more than 30 % away from the previous state
                let expandedToCollapsedDelta = metrics.expandedHeight - metrics.collapsedHeight
                if initialState.expansion == .collapsed {
                    if currentState.height >= metrics.collapsedHeight + 0.3 * expandedToCollapsedDelta {
                        // expand
                        return headersState(forFirstExpandedHeader: firstPartiallyExpandedIndex)
                    } else {
                        // collapse
                        return headersState(forFirstExpandedHeader: firstPartiallyExpandedIndex + 1)
                    }
                } else { // expanded
                    if currentState.height <= metrics.expandedHeight - 0.3 * expandedToCollapsedDelta {
                        // collapse
                        return headersState(forFirstExpandedHeader: firstPartiallyExpandedIndex + 1)
                    } else {
                        // expand
                        return headersState(forFirstExpandedHeader: firstPartiallyExpandedIndex)
                    }
                }
            } else {
                // for bigger velocities take the target height into account
                let targetTotalHeight = headersState.totalHeight + HeaderExpander
                    .minimumDragExpectedDuration * velocity
                // assign all extra total height to this header
                let targetHeaderHeight = targetTotalHeight - headersState.totalHeight + currentState.height
                if targetHeaderHeight >= (metrics.expandedHeight + metrics.collapsedHeight) / 2 {
                    // closer to expanded, expand:
                    return headersState(forFirstExpandedHeader: firstPartiallyExpandedIndex)

                } else {
                    // collapse
                    return headersState(forFirstExpandedHeader: firstPartiallyExpandedIndex + 1)
                }
            }
        }
        return nil
    }

    /// Since the headers are always collapsed from first to last and expanded from last to first
    /// setting first expanded header can be used to expand all headers with number >= headerNumber.
    /// To collapse all invoke with `headerNumber` = headers.count
    func headersState(forFirstExpandedHeader headerNumber: Int) -> HeadersState {
        let heights = (0 ..< headersInputMetrics.count).map { index in
            index >= headerNumber
                ? headersInputMetrics[index].expandedHeight
                : headersInputMetrics[index].collapsedHeight
        }
        return headersState(forHeights: heights)
    }
}
