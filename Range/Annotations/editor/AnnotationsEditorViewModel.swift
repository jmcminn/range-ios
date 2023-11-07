import Foundation
import OSLog
import UIKit

/// Used to keep the state of the current photo annotation editing session.
/// Based on this state the AnnotationsToolbarView is rendered.
///
/// Achtung: Even if annotating multiple photos in a gallery, there's still 1 `AnnotationsEditorViewModel` but there's many `AnnotationsEditor`s
///
class AnnotationsEditorViewModel: ObservableObject {
    /// currently annotated page in photos gallery
    var annotationsEditor: AnnotationsEditor? { didSet {
        currentAnnotationsEditorDidSet(previousAnnotationsEditor: oldValue)
    }}

    // TODO: 1891 is this needed?
    /// Is the AnnotationsToolbarView visible or not (hidden when keyboard is shown)
    @Published private(set) var toolbarVisible: Bool = true

    /// is the editing enabled for the current AnnotationsView (on if it's `installed`)
    @Published private(set) var editingEnabled: Bool = false

    /// Is the scribble mode enabled
    @Published private(set) var scribbleMode: Bool = false

    /// Current scribble thickness used for new scribbles (last user choice)
    /// If a scribble is selected it's the given scribble thickness
    @Published private(set) var currentScribbleThickness: Annotations.ScribbleThickness = .medium
    /// This is last user choice, unaffected by the current selected scribble, it is used for drawing
    @Published private(set) var lastPickedScribbleThickness: Annotations.ScribbleThickness = .medium

    /// Current scribble color used for new scribbles (last user choice)
    /// If a scribble is selected it's the given scribble color
    @Published private(set) var currentScribbleColor: UIColor = .Pink_03
    /// This is last user choice, unaffected by the current selected scribble, it is used for drawing
    @Published private(set) var lastPickedScribbleColor: UIColor = .Pink_03

    @Published private(set) var selectedAnnotation: AnnotationViewModel? = nil
    private var selectedAnnotationObservation: NSKeyValueObservation?
    private var editingAnnotationObservation: NSKeyValueObservation?
    private var currentAnnotationsEditorInstalledObservation: NSKeyValueObservation?

    func toggleScribbleMode() {
        scribbleMode.toggle()
        annotationsEditor?.setScribblingEnabled(scribbleMode)
    }

    @Published private(set) var scribbleAnnotationSelected: Bool = false
    @Published private(set) var textAnnotationSelected: Bool = false

    func setCurrentScribbleThickness(_ thickness: Annotations.ScribbleThickness) {
        guard let selectedAnnotation = selectedAnnotation as? ScribbleAnnotationViewModel else {
            Logger.annotations.warning("setCurrentScribbleThickness called when no scribble annotation selected")
            return
        }
        currentScribbleThickness = thickness
        lastPickedScribbleThickness = thickness
        selectedAnnotation.setThickness(thickness)
    }

    func setCurrentScribbleColor(_ color: UIColor) {
        // TODO: 1981 should work for all annnotations...
        guard let selectedAnnotation = selectedAnnotation as? ScribbleAnnotationViewModel else {
            Logger.annotations.warning("setCurrentScribbleThickness called when no scribble annotation selected")
            return
        }
        currentScribbleColor = color
        lastPickedScribbleColor = color
        selectedAnnotation.setColor(color)
    }

    /// Adds text in the middle of the current viewport, selects it and starts editing
    func insertTextAnnotation() {
        annotationsEditor?.insertTextAnnotation()
    }

    private func onAnnotationSelected(_ annotationVM: AnnotationViewModel?) {
        selectedAnnotation = annotationVM
        if let selectedAnnotation = selectedAnnotation as? ScribbleAnnotationViewModel {
            // TODO: 1981 some more generic way?
            currentScribbleThickness = selectedAnnotation.thickness ?? lastPickedScribbleThickness
            currentScribbleColor = selectedAnnotation.scribble.color
        }

        if let selectedAnnotation = selectedAnnotation {
            switch selectedAnnotation.annotation {
            case .scribble:
                scribbleAnnotationSelected = true
                textAnnotationSelected = false
            case .text:
                scribbleAnnotationSelected = false
                textAnnotationSelected = true
                // disable scribble mode when text annotation selected
                if scribbleMode { toggleScribbleMode() }
            }
        } else {
            scribbleAnnotationSelected = false
            textAnnotationSelected = false
        }
    }

    private func editingAnnotationChanged(_ annotationVM: AnnotationViewModel?) {
        toolbarVisible = annotationVM == nil
    }

    /// Unselect the currently selected annotation
    func unselectAnnotation() {
        annotationsEditor?.setSelected(nil)
    }

    /// Deletes the currently selected annotation
    func deleteAnnotation() {
        if let annotation = annotationsEditor?.selectedAnnotation {
            annotationsEditor?.deleteAnnotation(annotation)
        }
    }

    /// When switching the AnnotationsEditor currently handled by annotation session (so when changing a page in photos gallery)
    private func currentAnnotationsEditorDidSet(previousAnnotationsEditor: AnnotationsEditor?) {
        guard previousAnnotationsEditor != annotationsEditor else { return }

        previousAnnotationsEditor?.isActive = false
        selectedAnnotationObservation?.invalidate()
        editingAnnotationObservation?.invalidate()
        currentAnnotationsEditorInstalledObservation?.invalidate()
        onAnnotationSelected(annotationsEditor?.selectedAnnotation)
        editingAnnotationChanged(annotationsEditor?.editingAnnotation)
        editingEnabled = annotationsEditor?.installed ?? false
        if let annotationsEditor = annotationsEditor {
            selectedAnnotationObservation = annotationsEditor.observe(\.selectedAnnotation) { [weak self] _, _ in
                self?.onAnnotationSelected(annotationsEditor.selectedAnnotation)
            }
            editingAnnotationObservation = annotationsEditor.observe(\.editingAnnotation) { [weak self] _, _ in
                self?.editingAnnotationChanged(annotationsEditor.editingAnnotation)
            }
            currentAnnotationsEditorInstalledObservation = annotationsEditor.observe(
                \.installed,
                changeHandler: { [weak self] _, _ in
                    self?.editingEnabled = annotationsEditor.installed
                }
            )
            annotationsEditor.isActive = true
        }
    }
}
