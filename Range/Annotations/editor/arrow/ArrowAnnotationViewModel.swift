import Foundation
import UIKit

/// Holds the arrow annotation data and properties requried for view rendering, selection, etc.
class ArrowAnnotationViewModel: AnnotationViewModel {
    let arrow: ArrowAnnotation
    override var annotation: Annotation { arrow }

    /// The internal representation of path with points in image coordinates
    private var arrowPath: RangeBezierPath!
    /// The representation for annotation view with points in local viewFrame coordinates
    var arrowUIPath: UIBezierPath {
        arrowPath
            // translate so it's relative to view origin:
            .getTranslatedPath(x: -viewFrame.origin.x, y: -viewFrame.origin.y)
            .getUIBezierPath()
    }

    /// Unscaled arrow.lineWidth
    var thickness: Double { arrow.lineWidth / annotationsGeometry.scale }

    /// Initiates the view model with given annotation and annotationsGeometry
    init(arrow: ArrowAnnotation, annotationsGeometry: AnnotationsGeometry) {
        self.arrow = arrow
        super.init(annotationsGeometry: annotationsGeometry)

        zoomScale = 1
        updateViewFrame()
    }

    /// Overridden to allow dragging by start/end point
    override func shouldHandleDrag(startGestureLocation: CGPoint) -> (String, CGPoint)? {
        // The distance between control point and gesture start should be <= 40 (visible points).
        //
        // `points_distance * zoomScale <= 40` // * zoom scale to get us in the screen resolution and out of scrollView zoom dependent values
        // => `points_distance <= 40/zoomScale`
        // => `squared_points_distance <= (40/zoomScale)^2 = maxSquaredDistance
        let maxSquaredDistance = pow(40.0 / zoomScale, 2)

        // recognize control points drag first
        if CGPointDistanceSquared(from: startGestureLocation, to: arrow.startPoint) <= maxSquaredDistance {
            return ("startPoint", arrow.startPoint)
        } else if CGPointDistanceSquared(from: startGestureLocation, to: arrow.endPoint) <= maxSquaredDistance {
            return ("endPoint", arrow.endPoint)
        }
        // fallback to the view drag
        return super.shouldHandleDrag(startGestureLocation: startGestureLocation)
    }

    /// Moves the annotation to new origin. It updates the `viewFrame`.
    override func handleDrag(_ dragHandle: String, updatedDragOriginPoint origin: CGPoint) {
        if dragHandle == "startPoint" {
            arrow.startPoint = origin
        } else if dragHandle == "endPoint" {
            arrow.endPoint = origin
        } else {
            // move the whole annotation
            let originDelta = origin.deltaTo(viewFrame.origin)
            arrow.startPoint = arrow.startPoint.addTo(originDelta)
            arrow.endPoint = arrow.endPoint.addTo(originDelta)
        }
        updateViewFrame()
    }

    func setEndPoint(_ endPoint: CGPoint) {
        arrow.endPoint = endPoint
        updateViewFrame()
    }

    func setColor(_ color: UIColor) {
        arrow.color = color
    }

    /// Thickness impacts the `viewFrame`, so it also impacts the `uiPath`
    func setThickness(_ thickness: Double) {
        arrow.lineWidth = thickness * annotationsGeometry.scale
        updateViewFrame()
    }

    /// Update view frame from annotation data
    /// For arrow the view frame is the smallest rectangle to contain all four important points (startPoint, endPoint, and both tip end points)
    private func updateViewFrame() {
        arrowPath = RangeBezierPath.arrowPath(
            startPoint: arrow.startPoint,
            endPoint: arrow.endPoint,
            tipLength: Annotations.arrowTipLength * annotationsGeometry.scale
        )

        // Take the bounds.integral (so the enclosing rectangle with integer coordinates/width/height)
        let scribbleBoundsNoThickness = arrowPath.getUIBezierPath().bounds.integral

        // view bounds need to be extended to cover the whole width of the line
        let lineWidth = arrow.lineWidth

        viewFrame = scribbleBoundsNoThickness.insetBy(dx: -lineWidth, dy: -lineWidth)
    }

    override var debugDescription: String { "Arrow[\(arrow.id)]" }
    override var description: String { "Arrow[\(arrow.id)]" }

    /// Whether this annotation contains tap location and should be considered as tapped.
    /// If multiple annotations are tapped then the `distanceToTapLocation` will be checked and the annotation with smallest distance
    /// will be selected. If multiple annotations report the same distance (most likely 0 for overlapping annotations) then the selection will
    /// be based on the current order and selection state of annotations.
    override func containsTapLocation(_ location: CGPoint) -> Bool {
        // Implemented as in ScribbleAnnotationViewModel - see there for description
        let strokePath = arrowPath.getUIBezierPath().cgPath
            .copy(strokingWithWidth: 40 * annotationsGeometry.scale, lineCap: .round, lineJoin: .round, miterLimit: 1)
        return strokePath.contains(location)
    }

    /// Called when no annotations are returned on tap for `containsTapLocation`.
    /// This may be rough in a sence that the shape is not tapped (for scribble) but user tapped in the rectange containing the shape.
    override func roughlyContainsTapLocation(_ location: CGPoint) -> Bool {
        viewFrame.contains(location)
    }

    /// See description for `containsTapLocation`
    override func distanceToTapLocation(_ point: CGPoint) -> Float {
        arrowPath.getSimpleDistanceToPoint(point)
    }
}
