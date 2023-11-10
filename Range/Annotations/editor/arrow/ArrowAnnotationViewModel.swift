import Foundation
import UIKit

/// Holds the arrow annotation data and properties requried for view rendering, selection, etc.
class ArrowAnnotationViewModel: AnnotationViewModel {
    @objc private(set) dynamic var arrow: ArrowAnnotation

    override var annotation: Annotation { arrow.annotation }
    override var type: AnnotationType { arrow.type }

    /// The internal representation of path with points in image coordinates
    private var arrowPath: RangeBezierPath!
    /// The representation for annotation view with points in local viewFrame coordinates
    var arrowUIPath: UIBezierPath {
        arrowPath
            // translate so it's relative to view origin:
            .getTranslatedPath(x: -viewFrame.origin.x, y: -viewFrame.origin.y)
            .getUIBezierPath()
    }

    /// based on the arrow.lineWidth, optional as the line width may potentially not match any predefined thickness
    var thickness: Annotations.LineThickness? {
        let lineWidthBasedThickness = arrow.lineWidth / annotationsGeometry.scale
        return Annotations.LineThickness.allCases.first { $0.lineWidth == lineWidthBasedThickness }
    }

    /// Initiates the view model with given annotation and annotationsGeometry
    init(arrow: ArrowAnnotation, annotationsGeometry: AnnotationsGeometry) {
        self.arrow = arrow
        super.init(id: arrow.id, annotationsGeometry: annotationsGeometry)

        zoomScale = 1
        updateViewFrame()
    }

    /// Moves the annotation to new origin. It updates the `viewFrame`.
    override func handleDrag(_: String, updatedDragOriginPoint origin: CGPoint) {
        let originDelta = origin.deltaTo(viewFrame.origin)
        arrow.startPoint = arrow.startPoint.addTo(originDelta)
        arrow.endPoint = arrow.endPoint.addTo(originDelta)
        updateViewFrame()
    }

    func setColor(_ color: UIColor) {
        arrow.color = color
    }

    /// Thickness impacts the `viewFrame`, so it also impacts the `uiPath`
    func setThickness(_ thickness: Annotations.LineThickness) {
        arrow.lineWidth = thickness.lineWidth * annotationsGeometry.scale
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
