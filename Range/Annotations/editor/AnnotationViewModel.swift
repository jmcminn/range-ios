import Foundation

/// "Abstract"  parent for all annotation view models.
/// Swift doesn't support abstract classes so it's just a normal class with some functions not implemented (to be implemented by subclasses)
class AnnotationViewModel: NSObject, ObservableObject {
    var annotation: Annotation {
        fatalError("annotation to be provided by subclasses")
    }

    var id: String { annotation.id }
    var type: AnnotationType { annotation.type }

    /// annotationsGeometry is required for annotation to render and calculate it's size. All annotationes requried the scale, some annotations
    /// additinally need to know the image size (to calculate text wrapping, etc.)
    ///
    /// The scale used for annotations constants (like line thickness, font size, etc.)
    /// This is constant and determined when annotations are first saved for given image.
    /// This value determines the real values of size describing properties, like ScribbleAnnotation.lineWidth. So the line width is one of
    /// the values defined in Annotations.LineThickness enum, but the real value is the constant from this enum multiplied by scale.
    /// This is done so the thickness of line (of size of a font) is visually "correct", no matter what is the resolution of the image.
    /// (it wouldn't make sense to use the .medium scribble thickness, which is 6 pixels, without adjusting for an image that is 2000x3000 pixels,
    /// the thickness needs to be scaled, in this scale the scale = 5, so the actual line thickness in pixels is 6*5=30)
    let annotationsGeometry: AnnotationsGeometry

    /// whether this annotation is currently selected
    @Published var selected: Bool = false

    /// The frame for annotation view, scaled = in image coordinates.
    @Published var viewFrame: CGRect = .zero

    /// the current zoom level of the displayed view.
    /// We need it as not all parts of the annotation view should be zoomed when the annotations editor zoom changes (the border should
    /// keep the visible 2 pixels width)
    /// The reference (and initial) value is based on the scale value
    @Published var zoomScale: Double = 0

    init(annotationsGeometry: AnnotationsGeometry) {
        self.annotationsGeometry = annotationsGeometry
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

    /// If this selected annotation wants to be dragged given the gesture start point it should return a non nil String handle and the origin
    /// point for dragging.
    /// This handle will be later passed on drag finished.
    /// By default the implementation checks for gesture point being in viewFrame and returns "main" as a result.
    /// Some annotations may have some other dragging requirements - they may have some control points that control annotation
    /// size, direction, etc. So they can return different handles based on the drag location.
    func shouldHandleDrag(startGestureLocation: CGPoint) -> (String, CGPoint)? {
        if viewFrame.contains(startGestureLocation) {
            return ("main", viewFrame.origin)
        } else {
            return nil
        }
    }

    /// Called when dragging.
    /// - Parameters:
    ///   - stringHandle  the string returned from `shouldHandleDrag`
    ///   - updatedDragOriginPoint the origin point returned from `shouldHandleDrag` with the current drag translation applied
    func handleDrag(_: String, updatedDragOriginPoint _: CGPoint) {
        fatalError("handleDrag to be provided by subclasses")
    }
}
