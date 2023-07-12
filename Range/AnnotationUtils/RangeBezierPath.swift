import Foundation
import UIKit

/// UIBezierPath does not give access to the underlying data (https://stackoverflow.com/a/4855932) so we need this class to store all the lines/curves
/// This class can then be converted to UIBezierPath
/// It exposes a similar API to UIBezierPath so it can be easily replaced
class RangeBezierPath: Codable {
    enum Element: Equatable {
        case move(to: CGPoint)
        case addLine(to: CGPoint)
        case addCurve(to: CGPoint, controlPoint1: CGPoint, controlPoint2: CGPoint)
        case addQuadCurve(to: CGPoint, controlPoint: CGPoint)
        case close
    }

    private(set) var elements: [Element] = []

    // current point of the path - if path is closed the currentPoint is the previous point the path moved to
    // (the path may have multiple subpaths defined by multiples moves, each one can be closed or not)
    private(set) var currentPoint: CGPoint = CGPointZero

    init() {}

    /// Initializes with given points by connecting them with straight lines
    /// There must be at least 2 points, otherwise it returns nil
    convenience init?(polylineWithPoints points: [CGPoint]) {
        guard points.count >= 2 else { return nil }
        self.init()
        move(to: points[0])
        for point in points.suffix(from: 1) {
            addLine(to: point)
        }
    }

    convenience init(elements: [Element]) {
        self.init()
        elements.forEach(addElement(_:))
    }

    func move(to point: CGPoint) {
        addElement(.move(to: point))
    }

    func addLine(to point: CGPoint) {
        addElement(.addLine(to: point))
    }

    func addCurve(to endPoint: CGPoint, controlPoint1: CGPoint, controlPoint2: CGPoint) {
        addElement(.addCurve(to: endPoint, controlPoint1: controlPoint1, controlPoint2: controlPoint2))
    }

    func addQuadCurve(to endPoint: CGPoint, controlPoint: CGPoint) {
        addElement(.addQuadCurve(to: endPoint, controlPoint: controlPoint))
    }

    func close() {
        addElement(.close)
    }

    /// Add element to `elements` and update the `currentPoint`
    private func addElement(_ e: Element) {
        switch e {
        case let .move(to: point):
            fallthrough
        case let .addLine(to: point):
            fallthrough
        case let .addCurve(to: point, controlPoint1: _, controlPoint2: _):
            fallthrough
        case let .addQuadCurve(to: point, controlPoint: _):
            currentPoint = point
        case .close:
            // when closing the current point is set to last subpath beginning (where subpaths are
            // started by moves)
            if let lastMove = elements.last(where: {
                if case .move = $0 { return true }
                else { return false }
            }), case let .move(to: point) = lastMove {
                currentPoint = point
            } else {
                currentPoint = .zero
            }
        }

        elements.append(e)
    }

    private func elementsWithPointsTransformed(_ transform: (CGPoint) -> CGPoint) -> [Element] {
        elements.map { e in
            switch e {
            case let .move(to: point):
                return .move(to: transform(point))
            case let .addLine(to: point):
                return .addLine(to: transform(point))
            case let .addCurve(to: point, controlPoint1: controlPoint1, controlPoint2: controlPoint2):
                return .addCurve(
                    to: transform(point),
                    controlPoint1: transform(controlPoint1),
                    controlPoint2: transform(controlPoint2)
                )
            case let .addQuadCurve(to: point, controlPoint: controlPoint):
                return .addQuadCurve(to: transform(point), controlPoint: transform(controlPoint))
            case .close:
                return .close
            }
        }
    }

    /// Return the same path with all points scaled by given multiplier
    func getScaledPath(multiplier: CGFloat) -> RangeBezierPath {
        RangeBezierPath(elements: elementsWithPointsTransformed { $0.multiplyBy(multiplier) })
    }

    func getTranslatedPath(x: CGFloat, y: CGFloat) -> RangeBezierPath {
        RangeBezierPath(elements: elementsWithPointsTransformed { $0.translate(x: x, y) })
    }

    /// Returns the distance to point as if the path was a set of lines (and not curves)
    func getSimpleDistanceToPoint(_ p: CGPoint) -> Float {
        var distance = Float.infinity
        var previousPoint: CGPoint?
        for element in elements {
            switch element {
            case let .move(to: point):
                previousPoint = point
            case let .addLine(to: point): fallthrough
            case let .addCurve(to: point, controlPoint1: _, controlPoint2: _):
                if let previousPoint = previousPoint {
                    distance = min(distance, p.squaredDistanceToSegment(previousPoint, point))
                }
                previousPoint = point
            case let .addQuadCurve(to: point, controlPoint: _):
                if let previousPoint = previousPoint {
                    distance = min(distance, p.squaredDistanceToSegment(previousPoint, point))
                }
                previousPoint = point
            case .close: break
            }
        }
        return distance
    }

    func getUIBezierPath() -> UIBezierPath {
        let path = UIBezierPath()
        for element in elements {
            switch element {
            case let .move(to: point):
                path.move(to: point)
            case let .addLine(to: point):
                path.addLine(to: point)
            case let .addCurve(to: point, controlPoint1: controlPoint1, controlPoint2: controlPoint2):
                path.addCurve(to: point, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
            case let .addQuadCurve(to: point, controlPoint: controlPoint):
                path.addQuadCurve(to: point, controlPoint: controlPoint)
            case .close:
                path.close()
            }
        }

        return path
    }

    /// Create bezier path from set of points by using the Catmull-Rom interpolation
    /// It requires at least 4 points to work, otherwise nil will be returned
    /// In standard implementation the Catmull-Rom doesn't include the first and last point. This implementation adds the straight lines
    /// from/to first/last point to connect them with the resulting bezier path (when `closed` == `false`, otherwise this a closed loop anyway)
    static func interpolateWithCatmullRom(_ points: [CGPoint], closed: Bool, alpha: CGFloat) -> RangeBezierPath? {
        if points.count < 4 {
            return nil
        }

        let startIndex = closed ? 0 : 1
        let endIndex = closed ? points.count : points.count - 2

        let path = RangeBezierPath()
        for i in startIndex ..< endIndex {
            let p0 = points[i - 1 < 0 ? points.count - 1 : i - 1]
            let p1 = points[i]
            let p2 = points[(i + 1) % points.count]
            let p3 = points[(i + 2) % points.count]

            let d1 = p1.deltaTo(p0).length()
            let d2 = p2.deltaTo(p1).length()
            let d3 = p3.deltaTo(p2).length()

            var b1 = p2.multiplyBy(pow(d1, 2 * alpha))
            b1 = b1.deltaTo(p0.multiplyBy(pow(d2, 2 * alpha)))
            b1 = b1.addTo(p1
                .multiplyBy(2 * pow(d1, 2 * alpha) + 3 * pow(d1, alpha) * pow(d2, alpha) + pow(d2, 2 * alpha)))
            b1 = b1.multiplyBy(1.0 / (3 * pow(d1, alpha) * (pow(d1, alpha) + pow(d2, alpha))))

            var b2 = p1.multiplyBy(pow(d3, 2 * alpha))
            b2 = b2.deltaTo(p3.multiplyBy(pow(d2, 2 * alpha)))
            b2 = b2
                .addTo(p2.multiplyBy(2 * pow(d3, 2 * alpha) + 3 * pow(d3, alpha) * pow(d2, alpha) + pow(d2, 2 * alpha)))
            b2 = b2.multiplyBy(1.0 / (3 * pow(d3, alpha) * (pow(d3, alpha) + pow(d2, alpha))))

            if i == startIndex {
                if closed {
                    path.move(to: p1)

                } else {
                    // extra line from p0 to p1, not in original catmullRom
                    path.move(to: p0)
                    path.addLine(to: p1)
                }
            }

            path.addCurve(to: p2, controlPoint1: b1, controlPoint2: b2)
        }
        if !closed {
            // extra line to the last point
            path.addLine(to: points.last!)
        }

        if closed {
            path.close()
        }

        return path
    }

    // TODO: 1270 decode from path.d string
    required init(from _: Decoder) throws {
        elements = []
    }

    // TODO: 1270 encode to path.d string
    func encode(to _: Encoder) throws {}
}

// MARK: - to SVG path.d conversion

extension RangeBezierPath {
    /// RangeBezierPath doesn't keep it's original d definition. When creating RangeBezierPath from d string we don't keep the information
    /// whether the curves were absolute or relative or whether the curves were smooth or not. This doesn't impact how the curve looks
    /// but it does impact how it's converted to SVG. So converting from and back to SVG will not result in the same string!
    ///
    /// Reference: https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/d
    func convertToSVGPathD() -> String {
        elements.map(\.svgPathD).joined(separator: " ")
    }

    /// Convert SVG path d string to RangeBezierPath using modified parser from SwiftSVG framework (copied to Range code)
    /// The modification was to apply SwiftSVG D commands to RangeBezierPath and not UIBezierPath
    static func svgPathDToRangeBezierPath(_ dString: String) -> RangeBezierPath {
        let path = RangeBezierPath()
        var previousCommand: PreviousCommand?
        for command in PathDLexer(pathString: dString) {
            command.execute(on: path, previousCommand: previousCommand)
            previousCommand = command
        }
        return path
    }
}

extension RangeBezierPath.Element {
    var svgPathD: String {
        switch self {
        case let .move(to): return "M\(toSVGPathD(to))"
        case let .addLine(to): return "L\(toSVGPathD(to))"
        case let .addCurve(to, cp1, cp2): return "C\(toSVGPathD(cp1)) \(toSVGPathD(cp2)) \(toSVGPathD(to))"
        case let .addQuadCurve(to, cp): return "Q\(toSVGPathD(cp)) \(toSVGPathD(to))"
        case .close: return "Z"
        }
    }

    private func toSVGPathD(_ point: CGPoint) -> String {
        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: point.x as NSNumber)! + "," + formatter.string(from: point.y as NSNumber)!
    }
}
