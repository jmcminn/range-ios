import UIKit

/// Calculator for calculating header state based on the requested height
class HeaderExpanderCalculator {
    /// header metrics with which it was activated
    private let inputMetrics: HeadersInputMetrics

    init(inputMetrics: HeadersInputMetrics) {
        self.inputMetrics = inputMetrics
    }

    /// calculate header states for given total height of headers
    func headersState(forTotalHeight totalHeight: CGFloat) -> HeadersState {
        // output heights
        var heights = inputMetrics.metrics.map(\.collapsedHeight)
        // the height to be spread over n=>1 headers on top of their collapsed heights
        var heightToSpreadOverHeaders = totalHeight - inputMetrics.totalCollapsedHeadersHeight
        if heightToSpreadOverHeaders > 0 {
            var currentHeader = inputMetrics.metrics.count - 1
            while currentHeader > 0, heightToSpreadOverHeaders > 0 {
                // do not add more than the diff between expanded and collapsed
                let heightToAdd = min(
                    heightToSpreadOverHeaders,
                    inputMetrics[currentHeader].expandedHeight
                        - inputMetrics[currentHeader].collapsedHeight
                )
                heights[currentHeader] += heightToAdd
                heightToSpreadOverHeaders -= heightToAdd
                currentHeader -= 1
            }
            // header 0 gets all the remaining height
            heights[0] += heightToSpreadOverHeaders
        }
        return headersState(forHeights: heights)
    }

    /// Converts heights to states with appropriate expansion states based on the heights
    private func headersState(forHeights heights: [CGFloat]) -> HeadersState {
        let states: [HeaderState] = zip(inputMetrics.metrics, heights)
            .map { inputMetrics, height in
                if height > inputMetrics.expandedHeight {
                    return .overExpanded(height)
                } else if height == inputMetrics.expandedHeight {
                    return .expanded(height)
                } else if height > inputMetrics.collapsedHeight {
                    return .partiallyExpanded(height)
                } else {
                    return .collapsed(height)
                }
            }
        return HeadersState(states)
    }

    /// Calculates target headers state based on the initial state, current state and velocity.
    /// It handles the case when the headers started to change height from the initial state and are right now in some state with some
    /// velocity of change and we want to calculate the target state that only allows for collapsed/expanded and not some intermediary
    /// expansion states.
    /// - Parameters:
    ///     - initialHeadersState: state of the headers when gesture started
    ///     - headersState: current headers state
    ///     - velocity: velocity with which the headers height is changing
    /// - Returns: HeadersState if state needs to change, otherwise `nil`
    func targetHeadersState(forInitialState initialHeadersState: HeadersState,
                            currentState headersState: HeadersState,
                            velocity: CGFloat) -> HeadersState?
    {
        // if the first header is overexpanded just make it expanded
        if case .overExpanded = headersState.states.first {
            return self.headersState(forTotalHeight: inputMetrics.totalExpandedHeadersHeight)
        }

        // possibly expand or collapse a header if it's partially expanded
        // (there can only be 1 header in this state)
        if let firstPartiallyExpandedIndex = headersState.states
            .firstIndex(where: { if case .partiallyExpanded = $0 { return true } else { return false } })
        {
            let metrics = inputMetrics[firstPartiallyExpandedIndex]
            let initialState = initialHeadersState[firstPartiallyExpandedIndex]
            let currentState = headersState[firstPartiallyExpandedIndex]
            // low velocity
            if abs(velocity) < 150 {
                // for low velocity prefer changing state from the previous one (before gesture
                // started) if travelled more than 30 % away from the previous state
                let expandedToCollapsedDelta = metrics.expandedHeight - metrics.collapsedHeight
                if case .collapsed = initialState {
                    if currentState.height >= metrics.collapsedHeight + 0.3 * expandedToCollapsedDelta {
                        // expand
                        return self.headersState(forFirstExpandedHeader: firstPartiallyExpandedIndex)
                    } else {
                        // collapse
                        return self.headersState(forFirstExpandedHeader: firstPartiallyExpandedIndex + 1)
                    }
                } else { // expanded
                    if currentState.height <= metrics.expandedHeight - 0.3 * expandedToCollapsedDelta {
                        // collapse
                        return self.headersState(forFirstExpandedHeader: firstPartiallyExpandedIndex + 1)
                    } else {
                        // expand
                        return self.headersState(forFirstExpandedHeader: firstPartiallyExpandedIndex)
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
                    return self.headersState(forFirstExpandedHeader: firstPartiallyExpandedIndex)

                } else {
                    // collapse
                    return self.headersState(forFirstExpandedHeader: firstPartiallyExpandedIndex + 1)
                }
            }
        }
        return nil
    }

    /// Since the headers are always collapsed from first to last and expanded from last to first
    /// setting first expanded header can be used to expand all headers with number >= headerNumber.
    /// To collapse all invoke with `headerNumber` = headers.count
    func headersState(forFirstExpandedHeader headerNumber: Int) -> HeadersState {
        let heights = (0 ..< inputMetrics.metrics.count).map { index in
            index >= headerNumber
                ? inputMetrics[index].expandedHeight
                : inputMetrics[index].collapsedHeight
        }
        return headersState(forHeights: heights)
    }
}
