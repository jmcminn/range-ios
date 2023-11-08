import Foundation
import UIKit

/// A view for drawing. This view handles the user pan gesture and creates a shape, while the ScribbleView is for
/// displaying already created shapes.
class ScribblingView: UIView {
    /// The view is scaled (transformed) by this constant (multiplied)
    let scale: Double
    /// the thickness of the line
    var thickness: Annotations.LineThickness
    /// the inner color of the line
    var color: UIColor
    /// points recorded for annotation (not scaled)
    private var points: [CGPoint] = []
    /// Path to draw when user is drawing the line (scaled to ScribblingView scale)
    private var path = UIBezierPath()

    private(set) var gestureRecognizer: UIGestureRecognizer?

    /// Callback when user started another scribble
    var onScribbleStarted: (() -> Void)?
    /// Callback called with bezier path (not scaled) created whenever user completes a drag gesture
    var onScribbleCreated: ((RangeBezierPath) -> Void)?

    init(scale: Double, thickness: Annotations.LineThickness, color: UIColor) {
        self.scale = scale
        self.thickness = thickness
        self.color = color
        super.init(frame: .zero)
        backgroundColor = .clear
        transform = CGAffineTransform(scaleX: scale, y: scale)
        gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGesture))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Scales the point to this view coordinates and adds to points
    private func addPoint(_ point: CGPoint) {
        let scaledPoint = point.divideBy(scale)
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
        // lineWidth needs no scaling as the whole view is scaled
        let lineWidth = thickness.lineWidth
        ScribbleAnnotationRenderer.render(path: path, lineWidth: lineWidth, color: color)
    }

    @objc private func panGesture(gesture: UIGestureRecognizer) {
        if gesture.state == .began {
            onScribbleStarted?()
        }
        // The location is in non scaled coordinates
        // We round the coordinates, there's no point in dealing with non int coordinates of scribble
        // for photo (it'll also be more readable when stored in db)
        let location = gesture.location(in: gesture.view).roundCoordinates()

        addPoint(location)

        guard points.count >= 2 else { return }

        if gesture.state == .ended {
            let settings = AnnotationsDevSettings()

            let simplifiedPoints = settings.simplifyScribbleLine
                ? points.simplify(
                    tolerance: Float(scale), // 1
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
