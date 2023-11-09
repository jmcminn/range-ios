import Foundation
import UIKit

/// Holds the text annotation data and properties requried for view rendering, selection, etc.
class TextAnnotationViewModel: AnnotationViewModel {
    @objc private(set) dynamic var text: TextAnnotation

    /// The initial size for the box when calculating the annotation placement and the selection box when the text is empty (before user started typing)
    /// Unscaled
    static var initialBoxWidth: CGFloat = 84.0

    /// based on the text.fontSize, optional as the font size may potentially not match any predefined font sizes
    var fontSize: Annotations.FontSize? {
        let unscaledFontSize = text.fontSize / annotationsGeometry.scale
        return Annotations.FontSize.allCases.first { $0.size == unscaledFontSize }
    }

    /// whether the text of the annotation is currently being edited
    @objc dynamic var textEditing: Bool = false

    override var annotation: Annotation { text.annotation }

    /// Initiates the view model with given annotation and annotationsGeometry
    init(text: TextAnnotation, annotationsGeometry: AnnotationsGeometry) {
        self.text = text
        super.init(id: text.id, annotationsGeometry: annotationsGeometry)

        zoomScale = 1
        updateViewFrame()
    }

    /// Moves the annotation to new origin. It updates the `viewFrame`.
    override func setOrigin(_ origin: CGPoint) {
        text.position = origin
        updateViewFrame()
    }

    /// Font size impacts the `viewFrame`
    func setFontSize(_ fontSize: Annotations.FontSize) {
        text.fontSize = fontSize.size * annotationsGeometry.scale
        updateViewFrame()
    }

    func setColor(_ color: UIColor) {
        text.color = color
    }

    func setText(_ value: String) {
        text.text = value
        updateViewFrame()
    }

    /// Update view bounds from annotation data
    private func updateViewFrame() {
        viewFrame = CGRect(
            origin: text.position,
            size: TextAnnotationRenderer.annotationSize(
                position: text.position,
                text: text.text,
                fontSize: text.fontSize,
                annotationsGeometry: annotationsGeometry
            )
        )
    }

    override var debugDescription: String { "Text[\(text.id)]" }
    override var description: String { "Text[\(text.id)]" }

    /// Whether this annotation contains tap location and should be considered as tapped.
    /// If multiple annotations are tapped then the `distanceToTapLocation` will be checked and the annotation with smallest distance
    /// will be selected. If multiple annotations report the same distance (most likely 0 for overlapping annotations) then the selection will
    /// be based on the current order and selection state of annotations.
    override func containsTapLocation(_ location: CGPoint) -> Bool {
        viewFrame.contains(location)
    }

    /// Called when no annotations are returned on tap for `containsTapLocation`.
    /// This may be rough in a sence that the shape is not tapped (for scribble) but user tapped in the rectange containing the shape.
    override func roughlyContainsTapLocation(_ location: CGPoint) -> Bool {
        viewFrame.contains(location)
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
    static func initialAnnotationSize(position: CGPoint,
                                      text: String,
                                      fontSize: Double,
                                      annotationsGeometry: AnnotationsGeometry) -> CGSize
    {
        var size = TextAnnotationRenderer.annotationSize(
            position: position,
            text: text,
            fontSize: fontSize,
            annotationsGeometry: annotationsGeometry
        )
        size.width = max(size.width, ceil(initialBoxWidth * annotationsGeometry.scale))
        return size
    }
}
