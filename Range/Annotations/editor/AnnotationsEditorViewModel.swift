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

    /// Current line thickness used for new scribbles and arrows (last user choice)
    /// If an annotation is selected it's the given annotation thickness
    @Published private(set) var currentLineThickness: Annotations.LineThickness = .medium
    /// This is last user choice, unaffected by the current selected annotation, it is used for drawing
    @Published private(set) var lastPickedLineThickness: Annotations.LineThickness = .medium

    /// Current main color used for annotations (last user choice)
    /// If an annotation is selected it's the given annotation color
    @Published private(set) var currentColor: UIColor = .Red_03
    /// This is last user choice, unaffected by the current selected annotation, it is used for drawing
    @Published private(set) var lastPickedColor: UIColor = .Red_03

    /// Current text font size used for new annotations (last user choice)
    /// If a text annotation is selected it's the given annotation text font size
    @Published private(set) var currentTextFontSize: Annotations.FontSize = .medium
    /// This is last user choice, unaffected by the current selected annotation, it is used for new annotations
    @Published private(set) var lastPickedTextFontSize: Annotations.FontSize = .medium

    @Published private(set) var selectedAnnotation: AnnotationViewModel? = nil
    private var selectedAnnotationObservation: NSKeyValueObservation?
    private var editingAnnotationObservation: NSKeyValueObservation?
    private var currentAnnotationsEditorInstalledObservation: NSKeyValueObservation?

    func toggleScribbleMode() {
        scribbleMode.toggle()
        annotationsEditor?.setScribblingEnabled(scribbleMode)
    }

    func setCurrentLineThickness(_ thickness: Annotations.LineThickness) {
        currentLineThickness = thickness
        lastPickedLineThickness = thickness
        if let selectedAnnotation = selectedAnnotation as? ScribbleAnnotationViewModel {
            selectedAnnotation.setThickness(thickness)
        }
    }

    func setCurrentColor(_ color: UIColor) {
        currentColor = color
        lastPickedColor = color
        if let selectedAnnotation = selectedAnnotation as? ScribbleAnnotationViewModel {
            selectedAnnotation.setColor(color)
        } else if let selectedAnnotation = selectedAnnotation as? TextAnnotationViewModel {
            selectedAnnotation.setColor(color)
        }
    }

    func setCurrentFontSize(_ fontSize: Annotations.FontSize) {
        currentTextFontSize = fontSize
        lastPickedTextFontSize = fontSize
        if let selectedAnnotation = selectedAnnotation as? TextAnnotationViewModel {
            selectedAnnotation.setFontSize(fontSize)
        }
    }

    /// Adds text in the middle of the current viewport, selects it and starts editing
    func insertTextAnnotation() {
        annotationsEditor?.insertTextAnnotation()
    }

    private func onAnnotationSelected(_ annotationVM: AnnotationViewModel?) {
        selectedAnnotation = annotationVM
        if let selectedAnnotation = selectedAnnotation as? ScribbleAnnotationViewModel {
            currentLineThickness = selectedAnnotation.thickness ?? lastPickedLineThickness
            currentColor = selectedAnnotation.scribble.color
        } else if let selectedAnnotation = selectedAnnotation as? TextAnnotationViewModel {
            currentTextFontSize = selectedAnnotation.fontSize ?? lastPickedTextFontSize
            currentColor = selectedAnnotation.text.color
        }

        if let selectedAnnotation = selectedAnnotation, selectedAnnotation.type != .scribble {
            // disable scribble mode when an non-scribble annotation is selected
            if scribbleMode { toggleScribbleMode() }
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
