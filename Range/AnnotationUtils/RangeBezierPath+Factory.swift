import Foundation

/// Extension for creating preconfigured bazier paths
extension RangeBezierPath {
    /// Create an arrow from startPoint to endPoint with a tip that have 2 lines, both of tipLength and 45 degrees to arrow: -->
    static func arrowPath(startPoint: CGPoint, endPoint: CGPoint, tipLength: CGFloat) -> RangeBezierPath {
        let angleFromStartToEnd = endPoint.angle(from: startPoint)
        return RangeBezierPath(elements: [
            .move(to: startPoint),
            .addLine(to: endPoint),
            .addLine(to: endPoint.moving(distance: tipLength, at: angleFromStartToEnd + 135)),
            .move(to: endPoint),
            .addLine(to: endPoint.moving(distance: tipLength, at: angleFromStartToEnd - 135)),
        ])
    }
}
