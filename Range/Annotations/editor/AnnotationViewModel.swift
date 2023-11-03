import Foundation

/// "Abstract"  parent for all annotation view models.
/// Swift doesn't support abstract classes so it's just a normal class with some functions not implemented (to be implemented by subclasses)
class AnnotationViewModel: NSObject, AnnotationConvertible {
    /// The unique id of the annotation
    let id: String

    /// whether this annotation is currently selected
    @objc dynamic var selected: Bool = false

    /// the bounds that contain the path, scaled
    @objc dynamic var viewBounds: CGRect = .zero

    /// the current zoom level of the displayed view.
    /// We need it as not all parts of the annotation view should be zoomed when the annotations editor zoom changes (the border should
    /// keep the visible 2 pixels width)
    /// The reference (and initial) value is based on the scale value
    @objc dynamic var zoomScale: Double = 0

    /// Get the current annotation with all the changes applied in the view model
    var annotation: Annotation {
        fatalError("annotation to be provided by subclasses")
    }

    init(id: String) {
        self.id = id
    }

    /// Moves the annotation to new origin. It updates the `viewBounds` and `path` (which is not local to the annotation coordinate system)
    /// Please note that `uiPath` doesn't change when moving the scribble (as it's relative to the origin)
    func setOrigin(_: CGPoint) {
        fatalError("setOrigin to be provided by subclasses")
    }

    /// Whether this annotation contains tap location and should be considered as tapped.
    /// If multiple annotations are tapped then the `distanceToTapLocation` will be checked and the annotation with smallest distance
    /// will be selected. If multiple annotations report the same distance (most likely 0 for overlapping annotations) then the selection will
    /// be based on the current order and selection state of annotations.
    func containsTapLocation(_: CGPoint) -> Bool {
        fatalError("containsTapLocation to be provided by subclasses")
    }

    /// Called when no annotations are returned on tap for `containsTapLocation`.
    /// This may be rough in a sense that the shape is not tapped (for scribble) but user tapped in the rectange containing the shape.
    func roughlyContainsTapLocation(_: CGPoint) -> Bool {
        fatalError("roughlyContainsTapLocation to be provided by subclasses")
    }

    /// See description for `containsTapLocation`
    func distanceToTapLocation(_: CGPoint) -> Float {
        fatalError("distanceToTapLocation to be provided by subclasses")
    }
}
