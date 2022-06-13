import UIKit

/// Struct used for activating the `HeaderExpander`. Describes the metrics for one header
struct HeaderInputMetrics {
    var initialHeight: CGFloat // initial header height when activating the expander
    var collapsedHeight: CGFloat // minimal allowed height in the collapsed form
    var expandedHeight: CGFloat // maximal height in the expanded form (although the 1st header
    // might get over expanded)
}

/// Metrics for all the headers controlled by a `HeaderExpander`
struct HeadersInputMetrics {
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

    // for convenience add direct access to metrics with subscript operator
    subscript(index: Int) -> HeaderInputMetrics {
        metrics[index]
    }
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

/// State for all the headers controlled by a `HeaderExpander`
struct HeadersState {
    /// states
    let states: [HeaderState]
    /// precalculated total and other convenience properties
    let totalHeight: CGFloat
    let allCollapsed: Bool
    let heights: [CGFloat]
    init(_ states: [HeaderState]) {
        self.states = states
        totalHeight = states.map(\.height).reduce(0.0, +)
        allCollapsed = states.allSatisfy { $0.expansion == .collapsed }
        heights = states.map(\.height)
    }

    // for convenience add direct access to states with subscript operator
    subscript(index: Int) -> HeaderState {
        states[index]
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
