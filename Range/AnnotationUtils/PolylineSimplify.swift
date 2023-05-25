import Foundation

// MARK: - PolylineSimplify

// source: https://github.com/malcommac/SwiftSimplify
public enum PolylineSimplify {
    public static func simplify<P: Point2DRepresentable>(_ points: [P], tolerance: Float?,
                                                         highestQuality: Bool = false) -> [P]
    {
        guard points.count > 1 else {
            return points
        }

        let sqTolerance = tolerance != nil ? (tolerance! * tolerance!) : 1.0
        var result = highestQuality ? points : simplifyRadialDistance(points, tolerance: sqTolerance)
        result = simplifyDouglasPeucker(result, sqTolerance: sqTolerance)

        return result
    }

    private static func simplifyRadialDistance<P: Point2DRepresentable>(_ points: [P], tolerance: Float) -> [P] {
        guard points.count > 2 else {
            return points
        }

        var prevPoint = points.first!
        var newPoints = [prevPoint]
        var currentPoint: P!

        for i in 1 ..< points.count {
            currentPoint = points[i]
            if currentPoint.squaredDistanceFrom(prevPoint) > tolerance {
                newPoints.append(currentPoint)
                prevPoint = currentPoint
            }
        }

        if prevPoint.equalsTo(currentPoint) == false {
            newPoints.append(currentPoint)
        }

        return newPoints
    }

    private static func simplifyDPStep<P: Point2DRepresentable>(_ points: [P], first: Int, last: Int,
                                                                sqTolerance: Float,
                                                                simplified: inout [P])
    {
        guard last > first else {
            return
        }
        var maxSqDistance = sqTolerance
        var index = 0

        for currentIndex in first + 1 ..< last {
            let sqDistance = points[currentIndex].squaredDistanceToSegment(points[first], points[last])
            if sqDistance > maxSqDistance {
                maxSqDistance = sqDistance
                index = currentIndex
            }
        }

        if maxSqDistance > sqTolerance {
            if (index - first) > 1 {
                simplifyDPStep(points, first: first, last: index, sqTolerance: sqTolerance, simplified: &simplified)
            }
            simplified.append(points[index])
            if (last - index) > 1 {
                simplifyDPStep(points, first: index, last: last, sqTolerance: sqTolerance, simplified: &simplified)
            }
        }
    }

    private static func simplifyDouglasPeucker<P: Point2DRepresentable>(_ points: [P], sqTolerance: Float) -> [P] {
        guard points.count > 1 else {
            return []
        }

        let last = (points.count - 1)
        var simplied = [points.first!]
        simplifyDPStep(points, first: 0, last: last, sqTolerance: sqTolerance, simplified: &simplied)
        simplied.append(points.last!)

        return simplied
    }
}

// MARK: - Array Extension

public extension Array where Element: Point2DRepresentable {
    func simplify(tolerance: Float? = nil, highestQuality: Bool = true) -> [Element] {
        PolylineSimplify.simplify(self, tolerance: tolerance, highestQuality: highestQuality)
    }
}
