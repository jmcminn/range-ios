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

    func testConvertToSVGPathD() {
        let path = RangeBezierPath(elements: [
            .move(to: CGPoint(x: 10, y: -5)),
            .addLine(to: CGPoint(x: 20, y: 5)),
            .addCurve(
                to: CGPoint(x: 20, y: 10),
                controlPoint1: CGPoint(x: 21, y: 6),
                controlPoint2: CGPoint(x: 21, y: 9)
            ),
            .addQuadCurve(to: CGPoint(x: 25, y: 10), controlPoint: CGPoint(x: 22, y: 9.3)),
            .close,
        ])

        XCTAssertEqual(path.convertToSVGPathD(), "M10,-5 L20,5 C21,6 21,9 20,10 Q22,9.3 25,10 Z")
    }

    func testConvertSVGPathDToRangeBezierPath() {
        let dString = "M10,-5 L20,5 C21,6 21,9 20,10 Q22,9.3 25,10 Z"

        let path = RangeBezierPath.svgPathDToRangeBezierPath(dString)

        XCTAssertEqual(path.elements, [
            .move(to: CGPoint(x: 10, y: -5)),
            .addLine(to: CGPoint(x: 20, y: 5)),
            .addCurve(
                to: CGPoint(x: 20, y: 10),
                controlPoint1: CGPoint(x: 21, y: 6),
                controlPoint2: CGPoint(x: 21, y: 9)
            ),
            .addQuadCurve(to: CGPoint(x: 25, y: 10), controlPoint: CGPoint(x: 22, y: 9.3)),
            .close,
        ])
    }
    
    func testConvertSVGPathDToRangeBezierPath_numbersWithScientificNotation() {
        let dString = "M10,-5.1e+1 C110e-1,2 21.2,3e-16 22,3"

        let path = RangeBezierPath.svgPathDToRangeBezierPath(dString)

        XCTAssertEqual(path.elements, [
            .move(to: CGPoint(x: 10, y: -51)),
            .addCurve(
                to: CGPoint(x: 22, y: 3),
                controlPoint1: CGPoint(x: 11, y: 2),
                controlPoint2: CGPoint(x: 21.2, y: 0.0000000000000003)
            ),
        ])
    }
}
