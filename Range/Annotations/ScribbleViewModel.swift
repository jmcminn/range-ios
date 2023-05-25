import Foundation
import UIKit

class ScribbleViewModel: NSObject {
    /// The unique id of the annotation
    let id: String = UUID().uuidString.lowercased()
    /// the scribble view is scaled down (from the view layout perspective), so it's resolution is lower than the underlying photo.
    /// To preserve the real dimensions the view is transformed (scaled up) so 1 pixel of scribble cover several pixels of photo.
    /// This doesn't affect the end result of scribbling and generated annotation image, it's only done for the purpose of rendering
    /// in the annotations editor on iOS.
    /// For example when scale is 0.5, the view will have half the size but will be upscaled x2, so each pixel of scribble will "cover" 2 pixels of image (in 1 dimension)
    let scale: Double
    /// the bounds that contain the path, scaled
    private(set) var viewBounds: CGRect
    /// original path in the annotations coordinates space
    private(set) var path: RangeBezierPath
    /// translated and scaled so it can be drawn in the UI
    private(set) var uiPath: UIBezierPath
    /// the current zoom level of the displayed view.
    /// We need it as not all parts of the ScribbleView should be zoomed when the annotations editor zoom changes (the border should
    /// keep the visible 2 pixels width)
    /// The reference (and initial) value is the scale value
    @objc dynamic var zoomScale: Double
    /// whether this annotation is currently selected
    @objc dynamic var selected: Bool = false

    /// Initiates the view model with given scale and path
    init(scale: Double, path: RangeBezierPath) {
        self.scale = scale
        self.path = path

        // Take the bounds.integral (so the enclosing rectangle with integer coordinates/width/height)
        let scribbleBoundsNoThickness = path.getUIBezierPath().bounds.integral
        // TODO: 1183 line thickness is hardcoded here
        // view bounds need to be extended to cover the whole width of the line
        viewBounds = scribbleBoundsNoThickness.insetBy(dx: -6 / scale, dy: -6 / scale)
        uiPath = path
            // translate so it's relative to view origin:
            .getTranslatedPath(x: -viewBounds.origin.x, y: -viewBounds.origin.y)
            // scale down the path (as the view is scaled up):
            .getScaledPath(multiplier: scale)
            .getUIBezierPath()
        zoomScale = scale
        super.init()
    }

    /// Moves the annotation to new origin. It updates the `viewBounds` and `path` (which is not local to the annotation coordinate system)
    func setOrigin(_ origin: CGPoint) {
        let originDelta = origin.deltaTo(viewBounds.origin)
        viewBounds.origin = origin
        path = path.getTranslatedPath(x: originDelta.x, y: originDelta.y)
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(id)
        return hasher.finalize()
    }

    override var debugDescription: String { "Scribble[\(id)]" }
    override var description: String { "Scribble[\(id)]" }

    /// Whether this annotation contains tap location and should be considered as tapped.
    /// If multiple annotations are tapped then the `distanceToTapLocation` will be checked and the annotation with smallest distance
    /// will be selected. If multiple annotations report the same distance (most likely 0 for overlapping annotations) then the selection will
    /// be based on the current order and selection state of annotations.
    func containsTapLocation(_ location: CGPoint) -> Bool {
        // TODO: 1183 this only makes sense if we want to use convexHull for "roughlyContainsTapLocation"
        // otherwise the viewBounds kind of cover it anyway and multiple matches will still be
        // decided by "distanceToTapLocation"

        // check if the path actually contains the tap location
        // Do it by creating a stroking path (see it's documentation for details) that is 40 points
        // wide (divided by scale so it doesn't depend on the image resolution) but is 40 screen points.
        let strokePath = path.getUIBezierPath().cgPath
            .copy(strokingWithWidth: 40 / scale, lineCap: .round, lineJoin: .round, miterLimit: 1)
        return strokePath.contains(location)
    }

    /// Called when no annotations are returned on tap for `containsTapLocation`.
    /// This may be rough in a sence that the shape is not tapped (for scribble) but user tapped in the rectange containing the shape.
    func roughlyContainsTapLocation(_ location: CGPoint) -> Bool {
        viewBounds.contains(location)
    }

    /// See description for `containsTapLocation`
    func distanceToTapLocation(_ location: CGPoint) -> Float {
        path.getSimpleDistanceToPoint(location)
    }
}
