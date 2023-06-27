
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

    // TODO: 1290 remember for each scribble
    /// Current scribble thickness used for new scribbles (last user choice)
    var currentScribbleThickness: Annotations.ScribbleThickness = .medium

    /// Is the scribble mode enabled
    @Published private(set) var scribbleMode: Bool = false

    @Published var selectedAnnotation: ScribbleViewModel? = nil
    private var selectedAnnotationObservation: NSKeyValueObservation?

    func toggleScribbleMode() {
        scribbleMode.toggle()
        currentAnnotations?.setScribblingEnabled(scribbleMode)
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
        selectedAnnotation = currentAnnotations?.selectedAnnotation
        if let currentAnnotations = currentAnnotations {
            selectedAnnotationObservation = currentAnnotations.observe(\.selectedAnnotation) { [weak self] _, _ in
                self?.selectedAnnotation = currentAnnotations.selectedAnnotation
            }
        }
    }
}
