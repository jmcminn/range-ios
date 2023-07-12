
#if os(iOS) || os(tvOS)
    import UIKit
#elseif os(OSX)
    import AppKit
#endif

internal enum PathType {
    case absolute, relative
}

/**
 A protocol that describes an instance that can process an individual SVG Element
 */
internal protocol PathCommand: PreviousCommand {
    /**
     An array that stores processed coordinates values
     */
    var coordinateBuffer: [Double] { get set }

    /**
     The minimum number of coordinates needed to process the path command
     */
    var numberOfRequiredParameters: Int { get }

    /**
     The path type, relative or absolute
     */
    var pathType: PathType { get }

    /**
     Designated initializer that creates a relative or absolute `PathCommand`
     */
    init(pathType: PathType)

    /// ACHTUNG: this function was updated in Range to use RangeBezierPath instead of UIBezierPath
    /**
     Once the `numberOfRequiredParameters` has been met, this method will append new path to the passed path
     - Parameter path: The path to append a new path to
     - Parameter previousCommand: An optional previous command. Used primarily with the shortcut cubic and quadratic Bezier types
     */
    func execute(on path: RangeBezierPath, previousCommand: PreviousCommand?)
}

/**
 A protocol that describes an instance that represents an SVGElement right before the current one
 */
internal protocol PreviousCommand {
    /**
     An array that stores processed coordinates values
     */
    var coordinateBuffer: [Double] { get }

    /**
     The path type, relative or absolute
     */
    var pathType: PathType { get }
}

internal extension PathCommand {
    /**
     Default implementation for any `PathCommand` indicating where there are enough coordinates stored to be able to process the `SVGElement`
     */
    var canPushCommand: Bool {
        if self.numberOfRequiredParameters == 0 {
            return true
        }
        if self.coordinateBuffer.count == 0 {
            return false
        }
        if self.coordinateBuffer.count % self.numberOfRequiredParameters == 0 {
            return true
        }
        return false
    }

    /**
     Function that clears the current number buffer
     */
    mutating func clearBuffer() {
        coordinateBuffer.removeAll()
    }

    /**
     Adds a new coordinate to the buffer
     */
    mutating func pushCoordinate(_ coordinate: Double) {
        coordinateBuffer.append(coordinate)
    }

    /**
     Based on the `PathType` of this PathCommand, this function returns the relative or absolute point
     */
    func pointForPathType(_ point: CGPoint, relativeTo: CGPoint) -> CGPoint {
        switch pathType {
        case .absolute:
            return point
        case .relative:
            return CGPoint(x: point.x + relativeTo.x, y: point.y + relativeTo.y)
        }
    }
}

/////////////////////////////////////////////////////
//

// MARK: - Implementations

/**
 The `PathCommand` that corresponds to the SVG `M` or `m` command
 */
internal struct MoveTo: PathCommand {
    /// :nodoc:
    internal var coordinateBuffer = [Double]()

    /// :nodoc:
    internal let numberOfRequiredParameters = 2

    /// :nodoc:
    internal let pathType: PathType

    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }

    /**
     This will move the current point to `CGPoint(self.coordinateBuffer[0], self.coordinateBuffer[1])`.

     Sequential MoveTo commands should be treated as LineTos.

     From Docs (https://www.w3.org/TR/SVG2/paths.html#PathDataMovetoCommands):

     ```
     Start a new sub-path at the given (x,y) coordinates. M (uppercase) indicates that absolute coordinates will follow; m (lowercase) indicates that relative coordinates will follow. If a moveto is followed by multiple pairs of coordinates, the subsequent pairs are treated as implicit lineto commands. Hence, implicit lineto commands will be relative if the moveto is relative, and absolute if the moveto is absolute.
     ```
     */
    internal func execute(on path: RangeBezierPath, previousCommand: PreviousCommand? = nil) {
        if previousCommand is MoveTo {
            var implicitLineTo = LineTo(pathType: pathType)
            implicitLineTo.coordinateBuffer = [coordinateBuffer[0], coordinateBuffer[1]]
            implicitLineTo.execute(on: path)
            return
        }

        let point = pointForPathType(
            CGPoint(x: coordinateBuffer[0], y: coordinateBuffer[1]),
            relativeTo: path.currentPoint
        )
        path.move(to: point)
    }
}

/**
 The `PathCommand` that corresponds to the SVG `Z` or `z` command
 */
internal struct ClosePath: PathCommand {
    /// :nodoc:
    internal var coordinateBuffer = [Double]()

    /// :nodoc:
    internal let numberOfRequiredParameters = 0

    /// :nodoc:
    internal var pathType: PathType = .absolute

    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }

    /**
     Closes the current path
     */
    internal func execute(on path: RangeBezierPath, previousCommand _: PreviousCommand? = nil) {
        path.close()
    }
}

/**
 The `PathCommand` that corresponds to the SVG `L` or `l` command
 */
internal struct LineTo: PathCommand {
    /// :nodoc:
    internal var coordinateBuffer = [Double]()

    /// :nodoc:
    internal let numberOfRequiredParameters = 2

    /// :nodoc:
    internal let pathType: PathType

    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }

    /**
     Creates a line from the `path.currentPoint` to point `CGPoint(self.coordinateBuffer[0], coordinateBuffer[1])`
     */
    internal func execute(on path: RangeBezierPath, previousCommand _: PreviousCommand? = nil) {
        let point = pointForPathType(
            CGPoint(x: coordinateBuffer[0], y: coordinateBuffer[1]),
            relativeTo: path.currentPoint
        )
        path.addLine(to: point)
    }
}

/**
 The `PathCommand` that corresponds to the SVG `H` or `h` command
 */
internal struct HorizontalLineTo: PathCommand {
    /// :nodoc:
    internal var coordinateBuffer = [Double]()

    /// :nodoc:
    internal let numberOfRequiredParameters = 1

    /// :nodoc:
    internal let pathType: PathType

    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }

    /**
     Adds a horizontal line from the currentPoint to `CGPoint(self.coordinateBuffer[0], path.currentPoint.y)`
     */
    internal func execute(on path: RangeBezierPath, previousCommand _: PreviousCommand? = nil) {
        let x = coordinateBuffer[0]
        let point =
            (pathType == .absolute ? CGPoint(x: CGFloat(x), y: path.currentPoint.y) :
                CGPoint(x: path.currentPoint.x + CGFloat(x), y: path.currentPoint.y))
        path.addLine(to: point)
    }
}

/**
 The `PathCommand` that corresponds to the SVG `V` or `v` command
 */
internal struct VerticalLineTo: PathCommand {
    /// :nodoc:
    internal var coordinateBuffer = [Double]()

    /// :nodoc:
    internal let numberOfRequiredParameters = 1

    /// :nodoc:
    internal let pathType: PathType

    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }

    /**
     Adds a vertical line from the currentPoint to `CGPoint(path.currentPoint.y, self.coordinateBuffer[0])`
     */
    internal func execute(on path: RangeBezierPath, previousCommand _: PreviousCommand? = nil) {
        let y = coordinateBuffer[0]
        let point =
            (pathType == .absolute ? CGPoint(x: path.currentPoint.x, y: CGFloat(y)) :
                CGPoint(x: path.currentPoint.x, y: path.currentPoint.y + CGFloat(y)))
        path.addLine(to: point)
    }
}

/**
 The `PathCommand` that corresponds to the SVG `C` or `c` command
 */
internal struct CurveTo: PathCommand {
    /// :nodoc:
    internal var coordinateBuffer = [Double]()

    /// :nodoc:
    internal let numberOfRequiredParameters = 6

    /// :nodoc:
    internal let pathType: PathType

    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }

    /**
     Adds a cubic Bezier curve to `path`. The path will end up at `CGPoint(self.coordinateBuffer[4], self.coordinateBuffer[5])`. The control point for `path.currentPoint` will be `CGPoint(self.coordinateBuffer[0], self.coordinateBuffer[1])`. Then controle point for the end point will be CGPoint(self.coordinateBuffer[2], self.coordinateBuffer[3])
     */
    internal func execute(on path: RangeBezierPath, previousCommand _: PreviousCommand? = nil) {
        let startControl = pointForPathType(
            CGPoint(x: coordinateBuffer[0], y: coordinateBuffer[1]),
            relativeTo: path.currentPoint
        )
        let endControl = pointForPathType(
            CGPoint(x: coordinateBuffer[2], y: coordinateBuffer[3]),
            relativeTo: path.currentPoint
        )
        let point = pointForPathType(
            CGPoint(x: coordinateBuffer[4], y: coordinateBuffer[5]),
            relativeTo: path.currentPoint
        )
        path.addCurve(to: point, controlPoint1: startControl, controlPoint2: endControl)
    }
}

/**
 The `PathCommand` that corresponds to the SVG `S` or `s` command
 */
internal struct SmoothCurveTo: PathCommand {
    /// :nodoc:
    internal var coordinateBuffer = [Double]()

    /// :nodoc:
    internal let numberOfRequiredParameters = 4

    /// :nodoc:
    internal let pathType: PathType

    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }

    /**
     Shortcut cubic Bezier curve to that add a new path ending up at `CGPoint(self.coordinateBuffer[0], self.coordinateBuffer[1])` with a single control point in the middle.
     */
    internal func execute(on path: RangeBezierPath, previousCommand: PreviousCommand? = nil) {
        let point = pointForPathType(
            CGPoint(x: coordinateBuffer[2], y: coordinateBuffer[3]),
            relativeTo: path.currentPoint
        )
        let controlEnd = pointForPathType(
            CGPoint(x: coordinateBuffer[0], y: coordinateBuffer[1]),
            relativeTo: path.currentPoint
        )

        let controlStart: CGPoint
        if let previousCurveTo = previousCommand as? CurveTo {
            switch previousCurveTo.pathType {
            case .absolute:
                controlStart = CGPoint(
                    x: Double(2.0 * path.currentPoint.x) - previousCurveTo.coordinateBuffer[2],
                    y: Double(2.0 * path.currentPoint.y) - previousCurveTo.coordinateBuffer[3]
                )
            case .relative:
                let oldCurrentPoint = (
                    Double(path.currentPoint.x) - previousCurveTo.coordinateBuffer[4],
                    Double(path.currentPoint.y) - previousCurveTo.coordinateBuffer[5]
                )
                controlStart = CGPoint(
                    x: Double(2.0 * path.currentPoint.x) - (previousCurveTo.coordinateBuffer[2] + oldCurrentPoint.0),
                    y: Double(2.0 * path.currentPoint.y) - (previousCurveTo.coordinateBuffer[3] + oldCurrentPoint.1)
                )
            }
        } else if let previousSmoothCurveTo = previousCommand as? SmoothCurveTo {
            switch previousSmoothCurveTo.pathType {
            case .absolute:
                controlStart = CGPoint(
                    x: Double(2.0 * path.currentPoint.x) - previousSmoothCurveTo.coordinateBuffer[0],
                    y: Double(2.0 * path.currentPoint.y) - previousSmoothCurveTo.coordinateBuffer[1]
                )
            case .relative:
                let oldCurrentPoint = (
                    Double(path.currentPoint.x) - previousSmoothCurveTo.coordinateBuffer[2],
                    Double(path.currentPoint.y) - previousSmoothCurveTo.coordinateBuffer[3]
                )
                controlStart = CGPoint(
                    x: Double(2.0 * path.currentPoint.x) -
                        (previousSmoothCurveTo.coordinateBuffer[0] + oldCurrentPoint.0),
                    y: Double(2.0 * path.currentPoint.y) -
                        (previousSmoothCurveTo.coordinateBuffer[1] + oldCurrentPoint.1)
                )
            }
        } else {
            controlStart = path.currentPoint
        }
        path.addCurve(to: point, controlPoint1: controlStart, controlPoint2: controlEnd)
    }
}

/**
 The `PathCommand` that corresponds to the SVG `Q` or `q` command
 */
internal struct QuadraticCurveTo: PathCommand {
    /// :nodoc:
    internal var coordinateBuffer = [Double]()

    /// :nodoc:
    internal let numberOfRequiredParameters = 4

    /// :nodoc:
    internal let pathType: PathType

    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }

    internal func execute(on path: RangeBezierPath, previousCommand _: PreviousCommand? = nil) {
        let controlPoint = pointForPathType(
            CGPoint(x: coordinateBuffer[0], y: coordinateBuffer[1]),
            relativeTo: path.currentPoint
        )
        let point = pointForPathType(
            CGPoint(x: coordinateBuffer[2], y: coordinateBuffer[3]),
            relativeTo: path.currentPoint
        )
        path.addQuadCurve(to: point, controlPoint: controlPoint)
    }
}

/**
 The `PathCommand` that corresponds to the SVG `T` or `t` command
 */
internal struct SmoothQuadraticCurveTo: PathCommand {
    /// :nodoc:
    internal var coordinateBuffer = [Double]()

    /// :nodoc:
    internal let numberOfRequiredParameters = 2

    /// :nodoc:
    internal let pathType: PathType

    /// :nodoc:
    internal var previousControlPoint: CGPoint?

    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }

    internal func execute(on path: RangeBezierPath, previousCommand: PreviousCommand? = nil) {
        let point = pointForPathType(
            CGPoint(x: coordinateBuffer[0], y: coordinateBuffer[1]),
            relativeTo: path.currentPoint
        )

        var controlPoint: CGPoint
        if let previousQuadraticCurveTo = previousCommand as? QuadraticCurveTo {
            switch previousQuadraticCurveTo.pathType {
            case .absolute:
                controlPoint = CGPoint(
                    x: Double(2.0 * path.currentPoint.x) - previousQuadraticCurveTo.coordinateBuffer[0],
                    y: Double(2.0 * path.currentPoint.y) - previousQuadraticCurveTo.coordinateBuffer[1]
                )
            case .relative:
                let oldCurrentPoint = (
                    Double(path.currentPoint.x) - previousQuadraticCurveTo.coordinateBuffer[2],
                    Double(path.currentPoint.y) - previousQuadraticCurveTo.coordinateBuffer[3]
                )
                controlPoint = CGPoint(
                    x: Double(2.0 * path.currentPoint.x) - previousQuadraticCurveTo
                        .coordinateBuffer[0] + oldCurrentPoint.0,
                    y: Double(2.0 * path.currentPoint.y) - previousQuadraticCurveTo
                        .coordinateBuffer[1] + oldCurrentPoint.1
                )
            }
        } else {
            controlPoint = path.currentPoint
        }
        path.addQuadCurve(to: point, controlPoint: controlPoint)
    }
}

/**
 The `PathCommand` that corresponds to the SVG `A` or `a` command
 - TODO: Still needs an implementation
 */
internal struct EllipticalArc: PathCommand {
    /// :nodoc:
    internal var coordinateBuffer = [Double]()

    /// :nodoc:
    internal let numberOfRequiredParameters = 2

    /// :nodoc:
    internal let pathType: PathType

    /// :nodoc:
    internal init(pathType: PathType) {
        self.pathType = pathType
    }

    /// :nodoc:
    internal func execute(on _: RangeBezierPath, previousCommand _: PreviousCommand? = nil) {
        assertionFailure("Needs Implementation")
    }
}
