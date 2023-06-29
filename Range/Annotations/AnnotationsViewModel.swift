
import Foundation
import UIKit

/// Used to keep the state of the current photo annotation session.
/// Based on this state the AnnotationsToolbarView is rendered.
///
/// Achtung: Even if annotating multiple photos in a gallery, there's still 1 `AnnotationsViewModel` but there's many `Annotations`
///
class AnnotationsViewModel: ObservableObject {
    /// currently annotated page in photos gallery
    var currentAnnotations: AnnotationsView? { didSet { currentAnnotationsDidSet() }}

    /// is the editing enabled for the current AnnotationsView (on if it's `installed`)
    @Published private(set) var editingEnabled: Bool = false

    /// Is the scribble mode enabled
    @Published private(set) var scribbleMode: Bool = false

    /// Current scribble thickness used for new scribbles (last user choice)
    /// If a scribble is selected it's the given scribble thickness
    @Published private(set) var currentScribbleThickness: Annotations.ScribbleThickness = .medium
    /// This is last user choice, unaffected by the current selected scribble, it is used for drawing
    @Published private(set) var lastPickedScribbleThickness: Annotations.ScribbleThickness = .medium

    @Published private(set) var selectedAnnotation: ScribbleViewModel? = nil
    private var selectedAnnotationObservation: NSKeyValueObservation?
    private var currentAnnotationsViewInstalledObservation: NSKeyValueObservation?

    func toggleScribbleMode() {
        scribbleMode.toggle()
        currentAnnotations?.setScribblingEnabled(scribbleMode)
    }

    func setCurrentScribbleThickness(_ thickness: Annotations.ScribbleThickness) {
        currentScribbleThickness = thickness
        lastPickedScribbleThickness = thickness
        selectedAnnotation?.setThickness(thickness)
    }

    private func onAnnotationSelected(_ annotationVM: ScribbleViewModel?) {
        selectedAnnotation = annotationVM
        currentScribbleThickness = selectedAnnotation?.scribble.thickness ?? lastPickedScribbleThickness
    }

    /// Unselect the currently selected annotation
    func unselectAnnotation() {
        currentAnnotations?.setSelected(nil)
    }

    /// Deletes the currently selected annotation
    func deleteAnnotation() {
        if let annotation = currentAnnotations?.selectedAnnotation {
            currentAnnotations?.deleteAnnotation(annotation)
        }
    }

    /// When switching the Annotations currently handled by annotation session (so when changing a page in photos gallery)
    private func currentAnnotationsDidSet() {
        selectedAnnotationObservation?.invalidate()
        currentAnnotationsViewInstalledObservation?.invalidate()
        onAnnotationSelected(currentAnnotations?.selectedAnnotation)
        editingEnabled = currentAnnotations?.installed ?? false
        if let currentAnnotations = currentAnnotations {
            selectedAnnotationObservation = currentAnnotations.observe(\.selectedAnnotation) { [weak self] _, _ in
                self?.onAnnotationSelected(currentAnnotations.selectedAnnotation)
            }
            currentAnnotationsViewInstalledObservation = currentAnnotations.observe(
                \.installed,
                changeHandler: { [weak self] _, _ in
                    self?.editingEnabled = currentAnnotations.installed
                }
            )
        }
    }
}
