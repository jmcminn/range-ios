import Foundation
import UIKit

/// A view for drawing. This view handles the user pan gesture and creates a shape, while the ScribbleView is for
/// displaying already created shapes.
class ScribblingView: UIView {
    /// The view is scaled (transformed) by this constant (divided, so 1/scale)
    let scale: Double
    /// points recorded for annotation (not scaled)
    private var points: [CGPoint] = []
    /// Path to draw when user is drawing the line (scaled to ScribblingView scale)
    private var path = UIBezierPath()

    private(set) var gestureRecognizer: UIGestureRecognizer?

    /// Callback called with bezier path (not scaled) created whenever user completes a drag gesture
    var onScribbleCreated: ((RangeBezierPath) -> Void)?

    init(scale: Double) {
        self.scale = scale
        super.init(frame: .zero)
        backgroundColor = .clear
        transform = CGAffineTransform(scaleX: 1 / scale, y: 1 / scale)
        gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGesture))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Scales the point to this view coordinates and adds to points
    private func addPoint(_ point: CGPoint) {
        let scaledPoint = point.multiplyBy(scale)
        if points.isEmpty {
            path.move(to: scaledPoint)
        } else {
            path.addLine(to: scaledPoint)
        }
        points.append(point)
        setNeedsDisplay()
    }

    private func resetScribble() {
        points.removeAll()
        path = UIBezierPath()
        setNeedsDisplay()
    }

    override func draw(_: CGRect) {
        path.lineJoinStyle = .round
        path.lineCapStyle = .round

        path.lineWidth = 12
        UIColor.white.set()
        path.stroke()

        path.lineWidth = 6
        UIColor.Pink_03.set()
        path.stroke()
    }

    @objc private func panGesture(gesture: UIGestureRecognizer) {
        // The location is in non scaled coordinates
        let location = gesture.location(in: gesture.view)

        addPoint(location)

        guard points.count >= 2 else { return }

        if gesture.state == .ended {
            let settings = AnnotationsDevSettings()

            let simplifiedPoints = settings.simplifyScribbleLine
                ? points.simplify(
                    // TODO: 1290 is this dependent on the scribbleScale?
                    tolerance: Float(1 / scale), // 1
                    highestQuality: true
                )
                : points

            let path: RangeBezierPath? = settings.interpolateScribbleLine
                ? RangeBezierPath.interpolateWithCatmullRom(simplifiedPoints, closed: false, alpha: 0.5)
                : nil // non interpolated polyline is always a backup options for bezier, so no need to create it here

            if let path = path {
                // notify about new path
                onScribbleCreated?(path)
            } else if let path = RangeBezierPath(polylineWithPoints: simplifiedPoints) {
                // return polyline with given points if no interpolation can be constructed
                onScribbleCreated?(path)
            } else {
                // not enough points? do nothing (and reset the scribble)
            }
            // clear the current scribbling
            resetScribble()
        }
    }
}
