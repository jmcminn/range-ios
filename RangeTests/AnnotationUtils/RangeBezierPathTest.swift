
@testable import Range
import UIKit
import XCTest

final class RangeBezierPathTest: XCTestCase {
    /// Test that current point is correctly calculated when adding elements to path
    func testCurrentPoint() throws {
        let path = RangeBezierPath()
        XCTAssertEqual(path.currentPoint, .zero)

        path.move(to: CGPoint(x: 10, y: 5))
        XCTAssertEqual(path.currentPoint, CGPoint(x: 10, y: 5))

        path.addLine(to: CGPoint(x: 20, y: 5))
        XCTAssertEqual(path.currentPoint, CGPoint(x: 20, y: 5))

        path.close() // path closed, we're back at previous move position
        XCTAssertEqual(path.currentPoint, CGPoint(x: 10, y: 5))

        path.move(to: CGPoint(x: 30, y: 5))
        XCTAssertEqual(path.currentPoint, CGPoint(x: 30, y: 5))

        path.move(to: CGPoint(x: 40, y: 5))
        XCTAssertEqual(path.currentPoint, CGPoint(x: 40, y: 5))

        path.addCurve(
            to: CGPoint(x: 40, y: 10),
            controlPoint1: CGPoint(x: 40, y: 5),
            controlPoint2: CGPoint(x: 41, y: 5)
        )
        XCTAssertEqual(path.currentPoint, CGPoint(x: 40, y: 10))

        path.close() // path closed, we're back at previous move position
        XCTAssertEqual(path.currentPoint, CGPoint(x: 40, y: 5))

        path.close() // close again, this still refers to last position determined by previous close
        XCTAssertEqual(path.currentPoint, CGPoint(x: 40, y: 5))

        path.addLine(to: CGPoint(x: 50, y: 5))
        XCTAssertEqual(path.currentPoint, CGPoint(x: 50, y: 5))

        path.close() // close again, this still refers to last position determined by previous close
        XCTAssertEqual(path.currentPoint, CGPoint(x: 40, y: 5))
    }
}
