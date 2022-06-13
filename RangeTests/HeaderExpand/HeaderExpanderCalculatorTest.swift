@testable import Range

import XCTest

class HeaderExpanderCalculatorTest: XCTestCase {
    func testHeaderStateForTotalHeight_oneHeader() {
        let calc =
            HeaderExpanderCalculator(inputMetrics: [
                HeaderInputMetrics(initialHeight: 100, collapsedHeight: 50, expandedHeight: 100),
            ])

        XCTAssertEqual(
            calc.headersState(forTotalHeight: 20),
            [.collapsed(50)],
            "should return colapsed even if it's height is bigger than the requested height"
        )

        XCTAssertEqual(
            calc.headersState(forTotalHeight: 50),
            [.collapsed(50)],
            "should be collapsed"
        )

        XCTAssertEqual(
            calc.headersState(forTotalHeight: 60),
            [.partiallyExpanded(60)],
            "should be partially expanded"
        )

        XCTAssertEqual(
            calc.headersState(forTotalHeight: 100),
            [.expanded(100)],
            "should be partially expanded"
        )

        XCTAssertEqual(
            calc.headersState(forTotalHeight: 110),
            [.overExpanded(110)],
            "should be partially expanded"
        )
    }

    func testHeaderStateForTotalHeight_overExpandFirstHeaderOnly() {
        let calc =
            HeaderExpanderCalculator(inputMetrics: [
                HeaderInputMetrics(initialHeight: 10, collapsedHeight: 10, expandedHeight: 110),
                HeaderInputMetrics(initialHeight: 20, collapsedHeight: 20, expandedHeight: 120),
                HeaderInputMetrics(initialHeight: 30, collapsedHeight: 30, expandedHeight: 130),
            ])

        XCTAssertEqual(
            calc.headersState(forTotalHeight: 400),
            [.overExpanded(150), .expanded(120), .expanded(130)],
            "when height > total headers height it should expand all headers and over expand the first one"
        )
    }

    func testHeaderStateForTotalHeight_expandFromLast() {
        let calc =
            HeaderExpanderCalculator(inputMetrics: [
                HeaderInputMetrics(initialHeight: 10, collapsedHeight: 10, expandedHeight: 20),
                HeaderInputMetrics(initialHeight: 10, collapsedHeight: 10, expandedHeight: 20),
                HeaderInputMetrics(initialHeight: 10, collapsedHeight: 10, expandedHeight: 20),
            ])
        XCTAssertEqual(
            calc.headersState(forTotalHeight: 45),
            [.collapsed(10), .partiallyExpanded(15), .expanded(20)],
            "should expand from last"
        )
    }

    /// if first header is overexpanded just bring it to expanded no matter what is the velocity
    func testTargetHeaderStateWithVelocity_overExpanded() {
        let calc =
            HeaderExpanderCalculator(inputMetrics: [
                HeaderInputMetrics(initialHeight: 10, collapsedHeight: 10, expandedHeight: 20),
                HeaderInputMetrics(initialHeight: 10, collapsedHeight: 10, expandedHeight: 20),
            ])

        XCTAssertEqual(
            calc.targetHeadersState(
                forInitialState: [.collapsed(10), .collapsed(10)],
                currentState: [.overExpanded(30), .expanded(20)],
                velocity: 1000
            ),
            [.expanded(20), .expanded(20)],
            "should bring first over expanded header to expanded state"
        )

        XCTAssertEqual(
            calc.targetHeadersState(
                forInitialState: [.collapsed(10), .collapsed(10)],
                currentState: [.overExpanded(30), .expanded(20)],
                velocity: -1000
            ),
            [.expanded(20), .expanded(20)],
            "should bring first over expanded header to expanded state"
        )
    }

    /// for low velocity the target state doesn't use velocity at all and rather checks if expansion passed a 30% mark towards new state
    func testTargetHeaderStateWithVelocity_lowVelocity() {
        let calc =
            HeaderExpanderCalculator(inputMetrics: [
                HeaderInputMetrics(initialHeight: 10, collapsedHeight: 10, expandedHeight: 20),
            ])

        XCTAssertEqual(
            calc.targetHeadersState(
                forInitialState: [.collapsed(10)],
                currentState: [.partiallyExpanded(12)],
                velocity: 100
            ),
            [.collapsed(10)],
            "should get back to collapsed when slightly partially expanded with low velocity"
        )

        XCTAssertEqual(
            calc.targetHeadersState(
                forInitialState: [.expanded(20)],
                currentState: [.partiallyExpanded(18)],
                velocity: -100
            ),
            [.expanded(20)],
            "should get back to expanded when slightly partially collapsed with low velocity"
        )

        XCTAssertEqual(
            calc.targetHeadersState(
                forInitialState: [.collapsed(10)],
                currentState: [.partiallyExpanded(13)],
                velocity: 100
            ),
            [.expanded(20)],
            "should switch from collapsed to expanded when partially expanded by 30% with low velocity"
        )

        XCTAssertEqual(
            calc.targetHeadersState(
                forInitialState: [.expanded(20)],
                currentState: [.partiallyExpanded(17)],
                velocity: -100
            ),
            [.collapsed(10)],
            "should switch from expanded to collapsed when partially collapsed by 30% with low velocity"
        )
    }

    /// for higher velocity it's being used to calculate a target header but in a way that don't expands/collapses more than 1 header
    /// it will not expand/collapse any header if it isn't partially expanded currently as the assumption is that user has to initiate the
    /// expansion/collapse
    func testTargetHeaderStateWithVelocity_highVelocity() {
        let calc =
            HeaderExpanderCalculator(inputMetrics: [
                HeaderInputMetrics(initialHeight: 10, collapsedHeight: 10, expandedHeight: 20),
                HeaderInputMetrics(initialHeight: 10, collapsedHeight: 10, expandedHeight: 20),
            ])

        XCTAssertEqual(
            calc.targetHeadersState(
                forInitialState: [.collapsed(10), .collapsed(10)],
                currentState: [.collapsed(10), .expanded(20)],
                velocity: 1000
            ),
            nil,
            "don't expand if not partially expanded"
        )

        XCTAssertEqual(
            calc.targetHeadersState(
                forInitialState: [.collapsed(10), .collapsed(10)],
                currentState: [.partiallyExpanded(11), .expanded(20)],
                velocity: 1000
            ),
            [.expanded(20), .expanded(20)],
            "expand if partially expanded"
        )

        XCTAssertEqual(
            calc.targetHeadersState(
                forInitialState: [.collapsed(10), .collapsed(10)],
                currentState: [.partiallyExpanded(11), .expanded(20)],
                velocity: -1000
            ),
            [.collapsed(10), .expanded(20)],
            "collapse if partially expanded"
        )

        XCTAssertEqual(
            calc.targetHeadersState(
                forInitialState: [.collapsed(10), .collapsed(10)],
                currentState: [.collapsed(10), .partiallyExpanded(11)],
                velocity: 1000
            ),
            [.collapsed(10), .expanded(20)],
            "expand only the one partially expanded"
        )
    }
}
