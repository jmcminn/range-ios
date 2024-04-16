import Foundation
import UIKit

/// Holds the text annotation data and properties requried for view rendering, selection, etc.
class TextAnnotationViewModel: AnnotationViewModel {
    let text: TextAnnotation
    override var annotation: Annotation { text }

    /// based on the text.fontSize, optional as the font size may potentially not match any predefined font sizes
    var fontSize: Annotations.FontSize? { text.fontSizeEnum(annotationsGeometry.scale) }

    /// whether the text of the annotation is currently being edited
    @Published var textEditing: Bool = false { didSet {
        if textEditing {
            textOnEditingStarted = text.text
        }
    }}

    /// Every time the text annotation enters the editing mode (`textEditing` set to `true`) the text value is stored in this property.
    /// At the end of editing it can be used to check if there's any changes.
    private(set) var textOnEditingStarted: String

    /// Initiates the view model with given annotation and annotationsGeometry
    init(text: TextAnnotation, annotationsGeometry: AnnotationsGeometry) {
        self.text = text
        textOnEditingStarted = text.text
        super.init(annotationsGeometry: annotationsGeometry)

        zoomScale = 1
        updateViewFrame()
    }

    /// Moves the annotation to new origin. It updates the `viewFrame`.
    override func handleDrag(_: String, updatedDragOriginPoint origin: CGPoint) {
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
                text: text.text,
                fontSize: text.fontSize,
                annotationScale: annotationsGeometry.scale
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

    /// See description for `containsTapLocation`
    override func distanceToTapLocation(_: CGPoint) -> Float {
        // text annotation tap location checks are exact - if the tap is inside the view bounds.
        // So this function is only called when the tap is inside so no need to calculate the distance
        // as it is 0
        0
    }
}
