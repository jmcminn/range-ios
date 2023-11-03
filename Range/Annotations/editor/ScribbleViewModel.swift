import Foundation
import UIKit

/// Holds the scribble annotations data and properties requried for view rendering, selection, etc.
class ScribbleViewModel: AnnotationViewModel {
    @objc private(set) dynamic var scribble: ScribbleAnnotation

    /// the scribble view is scaled down (from the view layout perspective), so it's resolution is lower than the underlying photo.
    /// To preserve the real dimensions the view is transformed (scaled up) so 1 pixel of scribble cover several pixels of photo.
    /// This doesn't affect the end result of scribbling and generated annotation image, it's only done for the purpose of rendering
    /// in the annotations editor on iOS.
    /// For example when scale is 2, the view will have half the size but will be upscaled x2, so each pixel of scribble will "cover" 2 pixels of image (in 1 dimension)
    let scale: Double
    /// translated and scaled so it can be drawn in the UI
    private(set) var uiPath: UIBezierPath = .init()

    /// based on the scribble.lineWidth, optional as the line width may potentially not match any predefined thickness
    var thickness: Annotations.ScribbleThickness? {
        let lineWidthBasedThickness = scribble.lineWidth / scale
        return Annotations.ScribbleThickness.allCases.first { $0.lineWidth == lineWidthBasedThickness }
    }

    override var annotation: Annotation {
        scribble.annotation
    }

    /// Initiates the view model with given scale and path
    init(scale: Double, scribble: ScribbleAnnotation) {
        self.scribble = scribble
        self.scale = scale
        super.init(id: scribble.id)

        zoomScale = 1 / scale
        updateFromScribble()
    }

    /// Update view bounds and uiPath from scribble path
    private func updateFromScribble() {
        // Take the bounds.integral (so the enclosing rectangle with integer coordinates/width/height)
        let scribbleBoundsNoThickness = scribble.path.getUIBezierPath().bounds.integral
        // view bounds need to be extended to cover the whole width of the line
        let lineWidth = scribble.lineWidth
        viewBounds = scribbleBoundsNoThickness.insetBy(dx: -lineWidth, dy: -lineWidth)
        uiPath = scribble.path
            // translate so it's relative to view origin:
            .getTranslatedPath(x: -viewBounds.origin.x, y: -viewBounds.origin.y)
            // scale down the path (as the view is scaled up):
            .getScaledPath(multiplier: 1 / scale)
            .getUIBezierPath()
    }

    /// Moves the annotation to new origin. It updates the `viewBounds` and `path` (which is not local to the annotation coordinate system)
    /// Please note that `uiPath` doesn't change when moving the scribble (as it's relative to the origin)
    override func setOrigin(_ origin: CGPoint) {
        let originDelta = origin.deltaTo(viewBounds.origin)
        scribble.path = scribble.path.getTranslatedPath(x: originDelta.x, y: originDelta.y)
        // no need to `updateFromScribble`, it's only a change in origin
        viewBounds.origin = origin
    }

    /// Thickness impacts the `viewBounds`, so it also impacts the `uiPath`
    func setThickness(_ thickness: Annotations.ScribbleThickness) {
        scribble.lineWidth = thickness.lineWidth * scale
        updateFromScribble()
    }

    func setColor(_ color: UIColor) {
        scribble.color = color
    }

    override var debugDescription: String { "Scribble[\(scribble.id)]" }
    override var description: String { "Scribble[\(scribble.id)]" }

    /// Whether this annotation contains tap location and should be considered as tapped.
    /// If multiple annotations are tapped then the `distanceToTapLocation` will be checked and the annotation with smallest distance
    /// will be selected. If multiple annotations report the same distance (most likely 0 for overlapping annotations) then the selection will
    /// be based on the current order and selection state of annotations.
    override func containsTapLocation(_ location: CGPoint) -> Bool {
        // ACHTUNG: this approach makes more sense if we want to use convexHull for "roughlyContainsTapLocation"
        // otherwise the viewBounds kind of cover it anyway and multiple matches will still be
        // decided by "distanceToTapLocation".
        // The only advantage of path.copy(strokingWithWidth) is that
        // it creates a little bigger "tap area" in case of horizontal or vertical lines, which would
        // have a very small viewBounds.
        // Switching to convextHull in "roughlyContainsTapLocation" would be better as we would actually
        // see less shapes reporting as tapped, for example if there's a diagonal line and user taps
        // in the free corner, the bounds approach will report as tapped, while the convexHull would not.

        // check if the path actually contains the tap location
        // Do it by creating a stroking path (see it's documentation for details) that is 40 points
        // wide (divided by scale so it doesn't depend on the image resolution) but is 40 screen points.
        let strokePath = scribble.path.getUIBezierPath().cgPath
            .copy(strokingWithWidth: 40 * scale, lineCap: .round, lineJoin: .round, miterLimit: 1)
        return strokePath.contains(location)
    }

    /// Called when no annotations are returned on tap for `containsTapLocation`.
    /// This may be rough in a sence that the shape is not tapped (for scribble) but user tapped in the rectange containing the shape.
    override func roughlyContainsTapLocation(_ location: CGPoint) -> Bool {
        viewBounds.contains(location)
    }

    /// See description for `containsTapLocation`
    override func distanceToTapLocation(_ location: CGPoint) -> Float {
        scribble.path.getSimpleDistanceToPoint(location)
    }
}
