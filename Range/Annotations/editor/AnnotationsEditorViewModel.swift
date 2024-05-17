import Combine
import Foundation
import OSLog
import UIKit

/// Used to keep the state of the current photo annotation editing session.
/// Based on this state the AnnotationsToolbarView is rendered.
///
/// Achtung: Even if annotating multiple photos in a gallery, there's still 1 `AnnotationsEditorViewModel` but there's many `AnnotationsEditor`s
///
class AnnotationsEditorViewModel: ObservableObject {
    let userPreferences: UserPreferences

    /// currently annotated page in photos gallery
    var annotationsEditor: AnnotationsEditor? { didSet {
        currentAnnotationsEditorDidSet(previousAnnotationsEditor: oldValue)
    }}

    /// The enum for different modes of recognizing user gestures
    enum GesturesMode: Equatable {
        case normal // the user can select and drag annotations
        case drawing(_: AnnotationType) // the user gestures are recognized as drawing annotation of given type

        /// Returns the annotation currently being drawn (or nil if nothing is being drawn)
        var drawingAnnotation: AnnotationType? {
            switch self {
            case .normal: return nil
            case let .drawing(annotationType): return annotationType
            }
        }
    }

    /// Is the AnnotationsToolbarView visible or not (hidden when keyboard is shown)
    @Published private(set) var toolbarVisible: Bool = true

    @Published var recentTextSelectorVisible: Bool = false
    @Published var recentAnnotationsSelectorVisible: Bool = false

    /// is the editing enabled for the current AnnotationsView (on if it's `installed`)
    @Published private(set) var editingEnabled: Bool = false

    /// The currently selected gestures mode of operation
    @Published private(set) var gesturesMode: GesturesMode = .normal

    /// Current line thickness used for new scribbles and arrows (last user choice)
    /// If an annotation is selected it's the given annotation thickness
    @Published private(set) var currentLineThickness: Double
    /// This is last user choice, unaffected by the current selected annotation, it is used for drawing
    @Published private(set) var lastPickedLineThickness: Double
    /// The index in Annotations.lineThicknessOptions (it's a double as this is accepted by the Slider)
    @Published var currentLineThicknessOptionIndex: Double {
        didSet {
            updateCurrentLineThickness()
        }
    }

    /// Current main color used for annotations (last user choice)
    /// If an annotation is selected it's the given annotation color
    @Published private(set) var currentColor: UIColor
    /// This is last user choice, unaffected by the current selected annotation, it is used for drawing
    @Published private(set) var lastPickedColor: UIColor

    /// Current text font size used for new annotations (last user choice)
    /// If a text annotation is selected it's the given annotation text font size
    @Published private(set) var currentTextFontSize: Double
    /// This is last user choice, unaffected by the current selected annotation, it is used for new annotations
    @Published private(set) var lastPickedTextFontSize: Double
    /// The index in Annotations.fontSizeOptions (it's a double as this is accepted by the Slider)
    @Published var currentFontSizeOptionIndex: Double {
        didSet {
            updateCurrentFontSize()
        }
    }

    @Published private(set) var selectedAnnotation: AnnotationViewModel? = nil

    private var currentEditorSubscriptions = Set<AnyCancellable>()

    init(userPreferences: UserPreferences) {
        self.userPreferences = userPreferences
        let thickness = userPreferences.lastPickedAnnotationLineThickness
        currentLineThickness = thickness
        lastPickedLineThickness = thickness
        currentLineThicknessOptionIndex = Double(Annotations.lineThicknessOptionIndex(forValue: thickness))
        currentColor = userPreferences.lastPickedAnnotationColor
        lastPickedColor = userPreferences.lastPickedAnnotationColor
        let fontSize = userPreferences.lastPickedAnnotationFontSize
        currentTextFontSize = fontSize
        lastPickedTextFontSize = fontSize
        currentFontSizeOptionIndex = Double(Annotations.fontSizeOptionIndex(forValue: fontSize))
    }

    func setGesturesMode(_ mode: GesturesMode) {
        gesturesMode = mode
        if gesturesMode != .normal {
            // enabling any toggle tool deselects the currently selected annotation
            annotationsEditor?.setSelected(nil)
        }
        recentAnnotationsSelectorVisible = false
        updateCurrentAttributesBasedOnGesturesModeAndSelection()
    }

    /// The currentColor, thicknes, etc represent the user choices but also reflect the state of currently selected annotation and depend
    /// on the current gesturesMode.
    /// This function is called to update them whenever selection or gesturesMode changes.
    private func updateCurrentAttributesBasedOnGesturesModeAndSelection() {
        // if there's a selected annotation the attributes of this view model reflect the annotation
        // state, no matter if user is currently scribbling, etc (using potentially a different color...)
        if let selectedAnnotation = selectedAnnotation as? ScribbleAnnotationViewModel {
            currentLineThickness = selectedAnnotation.thickness
            currentColor = selectedAnnotation.scribble.color
        } else if let selectedAnnotation = selectedAnnotation as? TextAnnotationViewModel {
            currentTextFontSize = selectedAnnotation.fontSize
            currentColor = selectedAnnotation.text.color
        } else if let selectedAnnotation = selectedAnnotation as? ArrowAnnotationViewModel {
            currentLineThickness = selectedAnnotation.thickness
            currentColor = selectedAnnotation.arrow.color
        } else if let selectedAnnotation = selectedAnnotation as? LineAnnotationViewModel {
            currentLineThickness = selectedAnnotation.thickness
            currentColor = selectedAnnotation.line.color
        }

        // If there's no selected annotation and user is in drawing mode we want the current ui color
        // to reflect what's being used by the tool
        if gesturesMode != .normal, selectedAnnotation == nil {
            currentLineThickness = lastPickedLineThickness
            currentTextFontSize = lastPickedTextFontSize
            currentColor = lastPickedColor
        }

        currentLineThicknessOptionIndex = Double(Annotations.lineThicknessOptionIndex(forValue: currentLineThickness))
        currentFontSizeOptionIndex = Double(Annotations.fontSizeOptionIndex(forValue: currentTextFontSize))
    }

    func updateCurrentLineThickness() {
        let lineThicknessIndex = Int(currentLineThicknessOptionIndex)
        guard lineThicknessIndex >= 0, lineThicknessIndex < Annotations.lineThicknessOptions.count else { return }
        let thickness = Annotations.lineThicknessOptions[lineThicknessIndex]
        currentLineThickness = thickness
        lastPickedLineThickness = thickness
        userPreferences.lastPickedAnnotationLineThickness = thickness
        if let selectedAnnotation = selectedAnnotation as? ScribbleAnnotationViewModel {
            selectedAnnotation.setThickness(thickness)
        } else if let selectedAnnotation = selectedAnnotation as? ArrowAnnotationViewModel {
            selectedAnnotation.setThickness(thickness)
        } else if let selectedAnnotation = selectedAnnotation as? LineAnnotationViewModel {
            selectedAnnotation.setThickness(thickness)
        }
    }

    func setCurrentColor(_ color: UIColor) {
        guard let annotationsEditor = annotationsEditor else { return }
        currentColor = color
        lastPickedColor = color
        userPreferences.lastPickedAnnotationColor = color
        if let selectedAnnotation = selectedAnnotation as? ScribbleAnnotationViewModel {
            selectedAnnotation.setColor(color)
        } else if let selectedAnnotation = selectedAnnotation as? TextAnnotationViewModel {
            selectedAnnotation.setColor(color)
            userPreferences.addRecentTextAnnotation(selectedAnnotation.text, annotationsEditor.annotationsGeometry)
        } else if let selectedAnnotation = selectedAnnotation as? ArrowAnnotationViewModel {
            selectedAnnotation.setColor(color)
        } else if let selectedAnnotation = selectedAnnotation as? LineAnnotationViewModel {
            selectedAnnotation.setColor(color)
        }
    }

    func updateCurrentFontSize() {
        let fontSizeIndex = Int(currentFontSizeOptionIndex)
        guard fontSizeIndex >= 0, fontSizeIndex < Annotations.fontSizeOptions.count else { return }
        let fontSize = Annotations.fontSizeOptions[fontSizeIndex]
        currentTextFontSize = fontSize
        lastPickedTextFontSize = fontSize
        userPreferences.lastPickedAnnotationFontSize = fontSize
        if let annotationsEditor = annotationsEditor,
           let selectedAnnotation = selectedAnnotation as? TextAnnotationViewModel
        {
            selectedAnnotation.setFontSize(fontSize)
            userPreferences.addRecentTextAnnotation(selectedAnnotation.text, annotationsEditor.annotationsGeometry)
        }
    }

    func recentTextAnnotationSelected(_ annotation: TextAnnotation) {
        recentAnnotationsSelectorVisible = false
        annotationsEditor?.recentTextAnnotationSelected(annotation)
    }

    func recentAnnotationTextSelected(_ text: String) {
        recentTextSelectorVisible = false
        annotationsEditor?.recentAnnotationTextSelected(text)
    }

    /// Adds text in the middle of the current viewport, selects it and starts editing
    func insertTextAnnotation() {
        annotationsEditor?.insertTextAnnotation()
    }

    private func onAnnotationSelected(_ annotationVM: AnnotationViewModel?) {
        selectedAnnotation = annotationVM

        if selectedAnnotation != nil, gesturesMode != .normal {
            // Back to normal gestures mode = disable any toggled tool when user selects an annotation
            setGesturesMode(.normal)
        }

        updateCurrentAttributesBasedOnGesturesModeAndSelection()
    }

    private func editingAnnotationChanged(_ annotationVM: AnnotationViewModel?) {
        toolbarVisible = annotationVM == nil
    }

    /// Unselect the currently selected annotation
    func unselectAnnotation() {
        annotationsEditor?.setSelected(nil)
    }

    /// Duplicates the currently selected annotation
    func duplicateAnnotation() {
        guard let annotationVM = annotationsEditor?.selectedAnnotation else { return }
        annotationsEditor?.duplicateAnnotation(annotationVM)
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
        currentEditorSubscriptions.removeAll()
        onAnnotationSelected(annotationsEditor?.selectedAnnotation)
        editingAnnotationChanged(annotationsEditor?.editingAnnotation)
        editingEnabled = annotationsEditor?.installed ?? false
        if let annotationsEditor = annotationsEditor {
            annotationsEditor.$selectedAnnotation.sink { [weak self] selectedAnnotation in
                self?.onAnnotationSelected(selectedAnnotation)
            }.store(in: &currentEditorSubscriptions)
            annotationsEditor.$editingAnnotation.sink { [weak self] editingAnnotation in
                self?.editingAnnotationChanged(editingAnnotation)
            }.store(in: &currentEditorSubscriptions)
            annotationsEditor.$installed.sink { [weak self] installed in
                self?.editingEnabled = installed
            }.store(in: &currentEditorSubscriptions)
            annotationsEditor.isActive = true
        }
    }
}
