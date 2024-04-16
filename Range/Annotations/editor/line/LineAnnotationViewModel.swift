import Foundation
import UIKit

/// Holds the line annotation data and properties requried for view rendering, selection, etc.
class LineAnnotationViewModel: AnnotationViewModel {
    let line: LineAnnotation
    override var annotation: Annotation { line }

    /// The internal representation of path with points in image coordinates
    private var linePath: RangeBezierPath!
    /// The representation for annotation view with points in local viewFrame coordinates
    var lineUIPath: UIBezierPath {
        linePath
            // translate so it's relative to view origin:
            .getTranslatedPath(x: -viewFrame.origin.x, y: -viewFrame.origin.y)
            .getUIBezierPath()
    }

    /// Unscaled line.lineWidth
    var thickness: Double { line.lineWidth / annotationsGeometry.scale }

    /// Initiates the view model with given annotation and annotationsGeometry
    init(line: LineAnnotation, annotationsGeometry: AnnotationsGeometry) {
        self.line = line
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
        if CGPointDistanceSquared(from: startGestureLocation, to: line.startPoint) <= maxSquaredDistance {
            return ("startPoint", line.startPoint)
        } else if CGPointDistanceSquared(from: startGestureLocation, to: line.endPoint) <= maxSquaredDistance {
            return ("endPoint", line.endPoint)
        }
        // fallback to the view drag
        return super.shouldHandleDrag(startGestureLocation: startGestureLocation)
    }

    /// Moves the annotation to new origin. It updates the `viewFrame`.
    override func handleDrag(_ dragHandle: String, updatedDragOriginPoint origin: CGPoint) {
        if dragHandle == "startPoint" {
            line.startPoint = origin
        } else if dragHandle == "endPoint" {
            line.endPoint = origin
        } else {
            // move the whole annotation
            let originDelta = origin.deltaTo(viewFrame.origin)
            line.startPoint = line.startPoint.addTo(originDelta)
            line.endPoint = line.endPoint.addTo(originDelta)
        }
        updateViewFrame()
    }

    func setEndPoint(_ endPoint: CGPoint) {
        line.endPoint = endPoint
        updateViewFrame()
    }

    func setColor(_ color: UIColor) {
        line.color = color
    }

    /// Thickness impacts the `viewFrame`, so it also impacts the `uiPath`
    func setThickness(_ thickness: Double) {
        line.lineWidth = thickness * annotationsGeometry.scale
        updateViewFrame()
    }

    /// Update view frame from annotation data
    /// For line the view frame is the smallest rectangle to contain start and end points
    func updateViewFrame() {
        linePath = RangeBezierPath.linePath(startPoint: line.startPoint, endPoint: line.endPoint)

        // Take the bounds.integral (so the enclosing rectangle with integer coordinates/width/height)
        let scribbleBoundsNoThickness = linePath.getUIBezierPath().bounds.integral

        // view bounds need to be extended to cover the whole width of the line
        let lineWidth = line.lineWidth

        viewFrame = scribbleBoundsNoThickness.insetBy(dx: -lineWidth, dy: -lineWidth)
    }

    override var debugDescription: String { "Line[\(id)]" }
    override var description: String { "Line[\(id)]" }

    /// Whether this annotation contains tap location and should be considered as tapped.
    /// If multiple annotations are tapped then the `distanceToTapLocation` will be checked and the annotation with smallest distance
    /// will be selected. If multiple annotations report the same distance (most likely 0 for overlapping annotations) then the selection will
    /// be based on the current order and selection state of annotations.
    override func containsTapLocation(_ location: CGPoint) -> Bool {
        // Implemented as in ScribbleAnnotationViewModel - see there for description
        let tappableAreaWidth = max(
            40 / zoomScale, // 40 user visible points (40 is recommended minimal size for tappable things on iOS)
            2 * line.lineWidth
        )
        let strokePath = linePath.getUIBezierPath().cgPath
            .copy(strokingWithWidth: tappableAreaWidth, lineCap: .round, lineJoin: .round, miterLimit: 1)
        return strokePath.contains(location)
    }

    /// See description for `containsTapLocation`
    override func distanceToTapLocation(_ point: CGPoint) -> Float {
        linePath.getSimpleDistanceToPoint(point)
    }
}
