import Foundation
import UIKit

/// Holds the text annotation data and properties requried for view rendering, selection, etc.
class TextAnnotationViewModel: AnnotationViewModel {
    @objc private(set) dynamic var text: TextAnnotation

    /// The initial size for the box when calculating the annotation placement and the selection box when the text is empty (before user started typing)
    /// Unscaled
    static var initialBoxWidth: CGFloat = 84.0

    // TODO: 1981 move to AnnotationViewModel
    /// the scribble view is scaled down (from the view layout perspective), so it's resolution is lower than the underlying photo.
    /// To preserve the real dimensions the view is transformed (scaled up) so 1 pixel of scribble cover several pixels of photo.
    /// This doesn't affect the end result of scribbling and generated annotation image, it's only done for the purpose of rendering
    /// in the annotations editor on iOS.
    /// For example when scale is 2, the view will have half the size but will be upscaled x2, so each pixel of scribble will "cover" 2 pixels of image (in 1 dimension)
    let scale: Double

    /// based on the scribble.lineWidth, optional as the line width may potentially not match any predefined thickness
//    var thickness: Annotations.ScribbleThickness? {
//        let lineWidthBasedThickness = scribble.lineWidth / scale
//        return Annotations.ScribbleThickness.allCases.first { $0.lineWidth == lineWidthBasedThickness }
//    }

    /// whether the text of the annotation is currently being edited
    @objc dynamic var textEditing: Bool = false

    override var annotation: Annotation { text.annotation }

    /// Initiates the view model with given scale and path
    init(scale: Double, text: TextAnnotation) {
        self.text = text
        self.scale = scale
        super.init(id: text.id)

        zoomScale = 1
        updateFromAnnotation()
    }

    /// Update view bounds from annotation data
    private func updateFromAnnotation() {
        viewBounds = CGRect(
            origin: text.position,
            size: TextAnnotationRenderer.annotationSize(
                text: text.text, fontSize: text.fontSize, scale: scale
            )
        )
    }

    /// Moves the annotation to new origin. It updates the `viewBounds` and `path` (which is not local to the annotation coordinate system)
    /// Please note that `uiPath` doesn't change when moving the scribble (as it's relative to the origin)
    override func setOrigin(_ origin: CGPoint) {
        text.position = origin
        viewBounds.origin = origin
    }

    /// Thickness impacts the `viewBounds`, so it also impacts the `uiPath`
    func setThickness(_: Annotations.ScribbleThickness) {
//        scribble.lineWidth = thickness.lineWidth * scale
//        updateFromScribble()
    }

    func setColor(_ color: UIColor) {
        text.color = color
    }

    func setText(_ value: String) {
        text.text = value
        viewBounds.size = TextAnnotationRenderer.annotationSize(
            text: text.text, fontSize: text.fontSize, scale: scale
        )
    }

    override var debugDescription: String { "Text[\(text.id)]" }
    override var description: String { "Text[\(text.id)]" }

    /// Whether this annotation contains tap location and should be considered as tapped.
    /// If multiple annotations are tapped then the `distanceToTapLocation` will be checked and the annotation with smallest distance
    /// will be selected. If multiple annotations report the same distance (most likely 0 for overlapping annotations) then the selection will
    /// be based on the current order and selection state of annotations.
    override func containsTapLocation(_ location: CGPoint) -> Bool {
        viewBounds.contains(location)
    }

    /// Called when no annotations are returned on tap for `containsTapLocation`.
    /// This may be rough in a sence that the shape is not tapped (for scribble) but user tapped in the rectange containing the shape.
    override func roughlyContainsTapLocation(_ location: CGPoint) -> Bool {
        viewBounds.contains(location)
    }

    /// See description for `containsTapLocation`
    override func distanceToTapLocation(_: CGPoint) -> Float {
        // text annotation tap location checks are exact - if the tap is inside the view bounds.
        // So this function is only called when the tap is inside so no need to calculate the distance
        // as it is 0
        0
    }
}

extension TextAnnotationViewModel {
    /// Calculates the initial size of the annotation for given text with given font.
    /// Uses `TextAnnotationRenderer.annotationSize` function but adjusts for `TextAnnotationViewModel.initialBoxWidth`
    static func initialAnnotationSize(text: String, fontSize: Double, scale: Double) -> CGSize {
        var size = TextAnnotationRenderer.annotationSize(text: text, fontSize: fontSize, scale: scale)
        size.width = max(size.width, ceil(initialBoxWidth * scale))
        return size
    }
}
