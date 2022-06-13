import UIKit

/// Struct used for activating the `HeaderExpander`. Describes the metrics for one header
struct HeaderInputMetrics {
    var initialHeight: CGFloat // initial header height when activating the expander
    var collapsedHeight: CGFloat // minimal allowed height in the collapsed form
    var expandedHeight: CGFloat // maximal height in the expanded form (although the 1st header
    // might get over expanded)
}

/// Metrics for all the headers controlled by a `HeaderExpander`
struct HeadersInputMetrics: ExpressibleByArrayLiteral {
    /// the input metrics
    let metrics: [HeaderInputMetrics]
    /// precalculated total values
    let totalInitialHeadersHeight: CGFloat
    let totalCollapsedHeadersHeight: CGFloat
    let totalExpandedHeadersHeight: CGFloat
    init(_ metrics: [HeaderInputMetrics]) {
        self.metrics = metrics
        totalInitialHeadersHeight = metrics.map(\.initialHeight).reduce(0.0, +)
        totalCollapsedHeadersHeight = metrics.map(\.collapsedHeight).reduce(0.0, +)
        totalExpandedHeadersHeight = metrics.map(\.expandedHeight).reduce(0.0, +)
    }

    /// can directly assign from array of HeaderState(s)
    init(arrayLiteral metrics: HeaderInputMetrics...) {
        self = HeadersInputMetrics(metrics)
    }

    // for convenience add direct access to metrics with subscript operator
    subscript(index: Int) -> HeaderInputMetrics {
        metrics[index]
    }
}

/// Possible header states with corresponding heights
enum HeaderState: Equatable {
    case collapsed(CGFloat) // has its collapsed height
    case partiallyExpanded(CGFloat) // has the height between collapsed and expanded
    case expanded(CGFloat) // has its expanded height
    case overExpanded(CGFloat) // has height higher than the expanded height

    /// swift way of accessing the associated value
    /// exposed as a property for convenience
    var height: CGFloat {
        switch self {
        case let .collapsed(h), let .partiallyExpanded(h), let .expanded(h), let .overExpanded(h):
            return h
        }
    }
}

/// State for all the headers controlled by a `HeaderExpander`
struct HeadersState: Equatable, ExpressibleByArrayLiteral {
    /// states
    let states: [HeaderState]
    /// precalculated total and other convenience properties
    let totalHeight: CGFloat
    let allCollapsed: Bool
    let heights: [CGFloat]
    init(_ states: [HeaderState]) {
        self.states = states
        totalHeight = states.map(\.height).reduce(0.0, +)
        allCollapsed = states.allSatisfy { if case .collapsed = $0 { return true } else { return false } }
        heights = states.map(\.height)
    }

    /// can directly assign from array of HeaderState(s)
    init(arrayLiteral states: HeaderState...) {
        self = HeadersState(states)
    }

    /// for convenience add direct access to states with subscript operator
    subscript(index: Int) -> HeaderState {
        states[index]
    }

    /// equatable to check for states only (the rest is derived anyway)
    static func == (lhs: HeadersState, rhs: HeadersState) -> Bool {
        lhs.states == rhs.states
    }
}

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
