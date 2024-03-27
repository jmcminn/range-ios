import Combine
import Foundation
import OrderedCollections
import OSLog
import UIKit

/// Represent annotations editor for 1 photo
/// Shows the annotation views and handles the gestures
class AnnotationsEditor: NSObject {
    private weak var hostView: FullscreenImageGalleryPageView?
    // only needed for rendering the initial annotations when opening the annotations editor for a photo
    // It's not updated when user is editing annotations
    let initialAnnotations: Annotations?
    let viewModel: AnnotationsEditorViewModel

    /// whether this annotations editor is the current active editor (there might be multiple editors, one per gallery page, but only
    /// one is active at a time)
    var isActive: Bool = false { didSet {
        activate(isActive)
    }}

    /// whether the annotations were updated from the initialAnnotations
    private(set) var annotationsUpdated: Bool = false { didSet {
        NotificationCenter.default.post(name: AnnotationsEditor.AnnotationsUpdatedNotificationName, object: self)
    }}
    /// The name for the notification posted in NotificationCenter when the `annotationsUpdated` changes
    static let AnnotationsUpdatedNotificationName = Notification
        .Name("io.range.App.AnnotationsEditor.AnnotationsUpdated")

    /// view hosting all the annotation views
    let view = UIView()

    /// Describes the context for annotations rendering, including image size and annotations scale
    var annotationsGeometry: AnnotationsGeometry = .init(imageWidth: 1, imageHeight: 1, scale: 1)

    // whether the annotations are installed in the host view and ready to be edited
    @objc dynamic var installed: Bool = false
    // annotation currently selected by user
    @objc dynamic var selectedAnnotation: AnnotationViewModel?
    // annotaiton currently edited by user (only for annotations that are edited in place = text annotations)
    @objc dynamic var editingAnnotation: AnnotationViewModel?
    /// remember the origin of selected annotation when dragging begins (so it can be translated while dragging)
    var dragAnnotationOrigin: CGPoint?
    /// Handle returned by the annotation view model accepting the drag gesture
    var dragHandle: String?

    /// subview of `view` to which annotations are added
    let annotationsContainerView = UIView()

    /// The view for drawing (on top of annotationsView)
    var currentScribblingView: ScribblingView?

    /// handles the arrow drawing when in .arrowDrawing GesturesMode
    var arrowDrawing: ArrowDrawing?

    /// order in this dictionary is the order of annotations rendering, so last is on top
    private var annotationViewModels = OrderedDictionary<String, AnnotationViewModel>()
    private var annotationViews = OrderedDictionary<String, UIView>()

    /// Combine listeners for viewModel
    var subscriptions = Set<AnyCancellable>()

    /// The scrollView.contentOffset stored on keyboardWillShow to be reverted on keyboardWillHide
    private var scrollViewContentOffsetBeforeKeyboardAdjustment: CGPoint?
    /// text frame observation
    private var textAnnotationFrameObservation: NSKeyValueObservation?

    /// Gesture recognizers for tapping and dragging the annotations
    private var tapGestureRecognizer: UITapGestureRecognizer?
    private var panGestureRecognizer: UIPanGestureRecognizer?

    private var textAnnotationInputAccessoryView: UIView!

    init(
        hostView: FullscreenImageGalleryPageView,
        initialAnnotations: Annotations?,
        viewModel: AnnotationsEditorViewModel
    ) {
        self.hostView = hostView
        self.initialAnnotations = initialAnnotations
        self.viewModel = viewModel
        super.init()
        hostView.scrollView.forwardDelegateInvocations(to: self)
        subscribeToViewModel()

        NotificationCenter.default.addObserver(
            self, selector: #selector(checkAnnotationsUpdated),
            name: AnnotationUpdateNotificationName, object: nil
        )

        textAnnotationInputAccessoryView = setupTextAnnotationInputAccessoryView()
    }

    deinit {
        hostView?.scrollView.cancelForwardingDelegateInvocations(to: self)
        for subscription in subscriptions {
            subscription.cancel()
        }
        NotificationCenter.default.removeObserver(self)
    }

    private func subscribeToViewModel() {
        viewModel.$lastPickedLineThickness
            .sink { [weak self] in self?.currentScribblingView?.thickness = $0 }
            .store(in: &subscriptions)
        viewModel.$lastPickedColor
            .sink { [weak self] in self?.currentScribblingView?.color = $0 }
            .store(in: &subscriptions)
        viewModel.$gesturesMode
            .sink { [weak self] in self?.onGesturesModeSet($0) }
            .store(in: &subscriptions)
    }

    /// Adds the view to hostView
    func installView() {
        guard let hostView = hostView else { return }
        guard view.superview == nil else { return } // already installed
        guard let image = hostView.imageView.image else { return }
        let viewWidth = hostView.frame.width
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        guard viewWidth > 0, imageWidth > 0, imageHeight > 0 else { return }

        hostView.imageView.addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        view.addSubview(annotationsContainerView)
        annotationsContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let annotationsScale = initialAnnotations?.scale ?? min(imageWidth, imageHeight) / Annotations.referenceViewSize
        annotationsGeometry = AnnotationsGeometry(
            imageWidth: Int(imageWidth),
            imageHeight: Int(imageHeight),
            scale: annotationsScale
        )

        // show the initial annotations
        if let initialAnnotations = initialAnnotations {
            for annotation in initialAnnotations.annotations {
                // copy so we don't change the initial annotations (the initial values should not be
                // changed as we need them to compare new state vs initial, changing them would also
                // break the "cancel" functionality of the annotations editor)
                if let arrow = annotation as? ArrowAnnotation {
                    addArrow(arrow.copy() as! ArrowAnnotation)
                } else if let scribble = annotation as? ScribbleAnnotation {
                    addScribble(scribble.copy() as! ScribbleAnnotation)
                } else if let text = annotation as? TextAnnotation {
                    addText(text.copy() as! TextAnnotation)
                } else {
                    fatalError("Cannot add the annotation type \(annotation)")
                }
            }
        }

        installed = true
    }

    /// Setup when editor is activated/deactivated (becomes the current editor)
    private func activate(_ activate: Bool) {
        guard let hostView = hostView else { return }
        if activate {
            // install keyboard observers
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillShow),
                name: UIResponder.keyboardWillShowNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillHide),
                name: UIResponder.keyboardWillHideNotification,
                object: nil
            )
            // for annotation selection
            tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
            hostView.scrollView.addGestureRecognizer(tapGestureRecognizer!)

            // for annotation dragging
            panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGesture))
            panGestureRecognizer!.delegate = self
            hostView.scrollView.addGestureRecognizer(panGestureRecognizer!)

        } else {
            // hide any selectors and stop editing
            viewModel.recentTextSelectorVisible = false
            viewModel.recentAnnotationsSelectorVisible = false
            setEditing(nil)

            // remove keyboard observers
            NotificationCenter.default.removeObserver(self)

            // remove scroll view gesture recognizers
            if let tapGestureRecognizer = tapGestureRecognizer {
                hostView.scrollView.removeGestureRecognizer(tapGestureRecognizer)
            }
            if let panGestureRecognizer = panGestureRecognizer {
                hostView.scrollView.removeGestureRecognizer(panGestureRecognizer)
            }
        }
    }

    /// Add a scribble annotation and return its view
    func add(scribbleWithPath path: RangeBezierPath) {
        let scribble = ScribbleAnnotation(
            path: path,
            lineWidth: viewModel.lastPickedLineThickness.lineWidth * annotationsGeometry.scale,
            color: viewModel.lastPickedColor
        )
        addScribble(scribble)
    }

    @discardableResult private func addScribble(_ scribble: ScribbleAnnotation) -> ScribbleAnnotationViewModel {
        let scribbleVM = ScribbleAnnotationViewModel(scribble: scribble, annotationsGeometry: annotationsGeometry)
        if let hostView = hostView {
            scribbleVM.zoomScale = hostView.scrollView.zoomScale
        }
        let scribbleView = ScribbleAnnotationView(viewModel: scribbleVM)
        addAnnotation(scribbleVM, view: scribbleView)
        return scribbleVM
    }

    @discardableResult private func addArrow(_ arrow: ArrowAnnotation) -> ArrowAnnotationViewModel {
        let arrowVM = ArrowAnnotationViewModel(arrow: arrow, annotationsGeometry: annotationsGeometry)
        if let hostView = hostView {
            arrowVM.zoomScale = hostView.scrollView.zoomScale
        }
        let arrowAnnotationView = ArrowAnnotationView(viewModel: arrowVM)
        addAnnotation(arrowVM, view: arrowAnnotationView)
        return arrowVM
    }

    /// insert a duplicate of given annotation centered in the current viewport
    func recentTextAnnotationSelected(_ annotation: TextAnnotation) {
        guard let hostView = hostView else { return }
        let newAnnotation = annotation.duplicate(withOffset: .zero)
        // recent annotations are stored unscaled
        newAnnotation.fontSize = annotation.fontSize * annotationsGeometry.scale
        // calculate the position
        let centerOfTheScreenInImagePoint = view.convert(CGPoint(
            x: hostView.bounds.midX,
            y: hostView.bounds.midY
        ), from: hostView)
        let annotationSize = TextAnnotationRenderer.annotationSize(
            text: newAnnotation.text,
            fontSize: newAnnotation.fontSize,
            annotationScale: annotationsGeometry.scale
        )
        // position is top left of the box centered at the screen center
        newAnnotation.position = centerOfTheScreenInImagePoint.translate(
            x: -annotationSize.width / 2,
            y: -annotationSize.height / 2
        )
        UserDefaults.addRecentTextAnnotation(newAnnotation, annotationsGeometry)
        addText(newAnnotation)
    }

    /// insert the text into currently editing annotation
    func recentAnnotationTextSelected(_ text: String) {
        if let editingAnnotation = editingAnnotation,
           let textAnnotationView = annotationViews[editingAnnotation.id] as? TextAnnotationView
        {
            textAnnotationView.insertText(text)
        }
    }

    func insertTextAnnotation() {
        guard let hostView = hostView else {
            Logger.annotations.error("insertTextAnnotation: hostView not set!")
            return
        }

        let text = ""
        let fontSize = viewModel.lastPickedTextFontSize.size * annotationsGeometry.scale

        // insert new annotation in the visible center of the screen (to be precise to the left and up,
        // so it's center is in the center)
        // The usage of hostView.bounds and not hostView.frame is important here:
        // - We want the center of the view but we don't want the offset of the frame.
        // - Since we can be adding annotations to multiple photos, all FullscreenImageGalleryPageViews
        //   other than the first one have some non zero x offset.
        let centerOfTheScreenInImagePoint = view.convert(CGPoint(
            x: hostView.bounds.midX,
            y: hostView.bounds.midY
        ), from: hostView)
        let initialTextAnnotationSize = TextAnnotationRenderer.annotationSize(
            text: text,
            fontSize: fontSize,
            annotationScale: annotationsGeometry.scale
        )
        // position is top left of the box centered at the screen center
        let initialPosition = centerOfTheScreenInImagePoint.translate(
            x: -initialTextAnnotationSize.width / 2,
            y: -initialTextAnnotationSize.height / 2
        )
        let textAnnotation = TextAnnotation(
            text: text, position: initialPosition, fontSize: fontSize, color: viewModel.lastPickedColor
        )
        let textAnnotationVM = addText(textAnnotation)
        setSelected(textAnnotationVM)
        // start editing
        setEditing(textAnnotationVM)
    }

    @discardableResult private func addText(_ text: TextAnnotation) -> TextAnnotationViewModel {
        let textVM = TextAnnotationViewModel(text: text, annotationsGeometry: annotationsGeometry)
        if let hostView = hostView {
            textVM.zoomScale = hostView.scrollView.zoomScale
        }
        let textAnnotationView = TextAnnotationView(
            viewModel: textVM,
            inputAccessoryView: textAnnotationInputAccessoryView
        )
        addAnnotation(textVM, view: textAnnotationView)
        return textVM
    }

    private func addAnnotation(_ annotation: AnnotationViewModel, view: UIView) {
        annotationViewModels[annotation.id] = annotation
        annotationViews[annotation.id] = view

        annotationsContainerView.addSubview(view)
        view.frame = annotation.viewFrame
        setSelected(nil)

        checkAnnotationsUpdated()
    }

    func duplicateAnnotation(_ annotationVM: AnnotationViewModel) {
        let offsetSize = Annotations.duplicateAnnotationOffset * annotationsGeometry.scale
        let offset = CGPoint(x: offsetSize, y: offsetSize)

        let duplicate = annotationVM.annotation.duplicate(withOffset: offset)

        let duplicatedVM = if let arrow = duplicate as? ArrowAnnotation {
            addArrow(arrow)
        } else if let scribble = duplicate as? ScribbleAnnotation {
            addScribble(scribble)
        } else if let text = duplicate as? TextAnnotation {
            addText(text)
        } else {
            fatalError("duplicateAnnotation of annotation type \(duplicate) is not supported")
        }

        setSelected(duplicatedVM)
    }

    func deleteAnnotation(_ annotation: AnnotationViewModel) {
        if let view = annotationViews[annotation.id] {
            view.removeFromSuperview()
        }
        annotationViewModels[annotation.id] = nil
        annotationViews[annotation.id] = nil
        if annotation == selectedAnnotation {
            setSelected(nil)
        }

        checkAnnotationsUpdated()
    }

    @objc private func checkAnnotationsUpdated() {
        let initialAnnotations = initialAnnotations?.annotations ?? []
        let currentAnnotations = annotationViewModels.values.map(\.annotation)
        annotationsUpdated = initialAnnotations != currentAnnotations
    }
}

// MARK: - annotations save

extension AnnotationsEditor {
    func getAnnotations() -> Annotations? {
        guard let hostView = hostView, let image = hostView.imageView.image else { return nil }
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        guard imageWidth > 0, imageHeight > 0 else { return nil }

        if annotationViewModels.isEmpty {
            return nil
        } else {
            return Annotations(
                width: annotationsGeometry.imageWidth,
                height: annotationsGeometry.imageHeight,
                scale: annotationsGeometry.scale,
                annotationViewModels.values.map(\.annotation)
            )
        }
    }
}

// MARK: - scribble

extension AnnotationsEditor {
    private func onGesturesModeSet(_ mode: AnnotationsEditorViewModel.GesturesMode) {
        guard let hostView = hostView else { return }

        // scrolling between multiple photos is only enabled in normal mode, when adding a scribble
        // or arrow we want the scroll disabled
        hostView.scrollView.isScrollEnabled = mode == .normal

        setScribbling(enabled: mode == .scribbling)
        setArrowDrawing(enabled: mode == .arrowDrawing)
    }

    private func setScribbling(enabled: Bool) {
        guard let hostView = hostView else { return }
        if enabled {
            currentScribblingView = ScribblingView(
                scale: annotationsGeometry.scale,
                thickness: viewModel.lastPickedLineThickness,
                color: viewModel.lastPickedColor
            )
            currentScribblingView!.onScribbleStarted = { [weak self] in
                // unselect annotation on scribbling started
                self?.setSelected(nil)
            }
            currentScribblingView!.onScribbleCreated = { [weak self] path in
                self?.add(scribbleWithPath: path)
            }
            view.addSubview(currentScribblingView!)
            currentScribblingView!.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.height.equalToSuperview().dividedBy(annotationsGeometry.scale)
            }

            if let gestureRecognizer = currentScribblingView?.gestureRecognizer {
                hostView.imageView.addGestureRecognizer(gestureRecognizer)
            }

        } else {
            if let gestureRecognizer = currentScribblingView?.gestureRecognizer {
                hostView.imageView.removeGestureRecognizer(gestureRecognizer)
            }
            currentScribblingView?.removeFromSuperview()
            currentScribblingView = nil
        }
    }
}

// MARK: - arrow drawing

extension AnnotationsEditor {
    private func setArrowDrawing(enabled: Bool) {
        guard let hostView = hostView else { return }
        if enabled {
            let arrowDrawing = ArrowDrawing()
            arrowDrawing.onDrawingBegan = { [weak self] in
                // unselect annotation on drawing started
                self?.setSelected(nil)
            }
            arrowDrawing.onAnnotationCreated = { [weak self] startPoint, endPoint in
                guard let self = self else { return nil }
                let annotation = ArrowAnnotation(
                    startPoint: startPoint,
                    endPoint: endPoint,
                    lineWidth: self.viewModel.lastPickedLineThickness.lineWidth * self.annotationsGeometry.scale,
                    color: self.viewModel.lastPickedColor
                )
                return addArrow(annotation)
            }
            if let gestureRecognizer = arrowDrawing.gestureRecognizer {
                hostView.imageView.addGestureRecognizer(gestureRecognizer)
            }
            self.arrowDrawing = arrowDrawing
        } else {
            guard let arrowDrawing = arrowDrawing else { return }
            if let gestureRecognizer = arrowDrawing.gestureRecognizer {
                hostView.imageView.removeGestureRecognizer(gestureRecognizer)
            }
        }
    }
}

// MARK: - selection

extension AnnotationsEditor {
    @objc private func viewTapped(gesture: UIGestureRecognizer) {
        // find tapped annotation
        let location = gesture.location(in: view)

        let tappedAnnotation = tappedAnnotation(atLocation: location)
        setSelected(tappedAnnotation)

        viewModel.setGesturesMode(.normal)
        viewModel.recentTextSelectorVisible = false
        viewModel.recentAnnotationsSelectorVisible = false
    }

    /// Discover annotation when tapping at given location
    private func tappedAnnotation(atLocation location: CGPoint) -> AnnotationViewModel? {
        // strictly contains the tap location
        var tappedAnnotations = annotationViewModels.values.filter { $0.containsTapLocation(location) }
        if tappedAnnotations.isEmpty {
            // fallback to "rough containment"
            tappedAnnotations = annotationViewModels.values.filter { $0.roughlyContainsTapLocation(location) }
        }

        if tappedAnnotations.count == 0 {
            return nil
        } else if tappedAnnotations.count == 1 {
            // select if only one annotation matches
            return tappedAnnotations[0]
        } else {
            // decide which annotation to select by doing some more exact tap recognition
            // and select the annotation closest to tap location
            let distancesToTap = tappedAnnotations.map { $0.distanceToTapLocation(location) }
            let minIndex = zip(distancesToTap.indices, distancesToTap).min(by: { $0.1 < $1.1 })?.0 ?? 0
            let closestAnnotation = tappedAnnotations[minIndex]
            return closestAnnotation
        }
    }

    /// select given annotation or deselect if nil
    func setSelected(_ selectedAnnotation: AnnotationViewModel?) {
        let previousSelectedAnnotation = self.selectedAnnotation

        self.selectedAnnotation = selectedAnnotation

        if previousSelectedAnnotation != selectedAnnotation {
            // unselect the previous one and select new one
            previousSelectedAnnotation?.selected = false
            // stop editing previous text annotation
            setEditing(nil)
            selectedAnnotation?.selected = true
            // the selected annotation should be on top
            if let selectedAnnotation = selectedAnnotation {
                // change the order in annotation view models
                if let annotation = annotationViewModels.removeValue(forKey: selectedAnnotation.id) {
                    annotationViewModels[annotation.id] = annotation
                    // move the view to the top
                    annotationsContainerView.bringSubviewToFront(annotationViews[annotation.id]!)
                }
            }
        } else {
            // same annotation selected again - start editing selected annotation
            if let textAnnotation = selectedAnnotation as? TextAnnotationViewModel {
                setEditing(textAnnotation)
            }
        }

        checkAnnotationsUpdated()
    }

    func setEditing(_ editingAnnotation: TextAnnotationViewModel?) {
        // mark the previous one as not editing
        if editingAnnotation != self.editingAnnotation,
           let textAnnotationVM = self.editingAnnotation as? TextAnnotationViewModel
        {
            let textBeforeEditing = textAnnotationVM.textOnEditingStarted
            textAnnotationVM.textEditing = false
            if textAnnotationVM.text.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // no text provided (other than spaces), remove:
                deleteAnnotation(textAnnotationVM)
            } else {
                // store the text in recent texts when editing ended
                // but only if it has changed during the editing session
                if textBeforeEditing != textAnnotationVM.text.text {
                    UserDefaults.addRecentAnnotationTexts([textAnnotationVM.text])
                    UserDefaults.addRecentTextAnnotation(textAnnotationVM.text, annotationsGeometry)
                }
            }
        }
        // update the currently editing
        self.editingAnnotation = editingAnnotation
        // mark new one as editing
        if let editingAnnotation = editingAnnotation {
            editingAnnotation.textEditing = true
        }
    }
}

// MARK: - drag annotations

extension AnnotationsEditor: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        // Only recognize the annotations dragging when in .normal gestures mode (so no scribbling, etc.)
        guard viewModel.gesturesMode == .normal else { return false }

        viewModel.recentTextSelectorVisible = false
        viewModel.recentAnnotationsSelectorVisible = false
        let location = gesture.location(in: view)

        // 1. give priority to currently selected annotation and check if it should drag
        // (and block other gestures like drawing or changing the gallery pages)
        if let selectedAnnotation = selectedAnnotation,
           let (dragHandle, dragAnnotationOrigin) = selectedAnnotation.shouldHandleDrag(startGestureLocation: location)
        {
            self.dragHandle = dragHandle
            self.dragAnnotationOrigin = dragAnnotationOrigin
            return true
        }

        // 2. if the selected annotation is not being dragged or there's no selected annotation
        // then check if any other annotation should be autoselected and dragged
        if let annotationAtLocation = tappedAnnotation(atLocation: location),
           annotationAtLocation != selectedAnnotation,
           let (dragHandle, dragAnnotationOrigin) = annotationAtLocation
           .shouldHandleDrag(startGestureLocation: location)
        {
            setSelected(annotationAtLocation)
            self.dragHandle = dragHandle
            self.dragAnnotationOrigin = dragAnnotationOrigin
            return true
        }

        dragHandle = nil
        return false
    }

    @objc private func panGesture(gesture: UIPanGestureRecognizer) {
        guard let selectedAnnotation = selectedAnnotation,
              let dragHandle = dragHandle,
              let dragAnnotationOrigin = dragAnnotationOrigin else { return }

        let translation = gesture.translation(in: view)
        let updatedDragOriginPoint = translation.addTo(dragAnnotationOrigin)
        selectedAnnotation.handleDrag(dragHandle, updatedDragOriginPoint: updatedDragOriginPoint)
    }
}

// MARK: - parent scroll view delegate

extension AnnotationsEditor: UIScrollViewDelegate {
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        for annotation in annotationViewModels.values {
            annotation.zoomScale = scrollView.zoomScale
        }
    }
}

// MARK: keyboard handling

extension AnnotationsEditor {
    /// Adjust the textView constraints when keyboard shows
    @objc func keyboardWillShow(notification: NSNotification) {
        // Get required info out of the notification
        if let userInfo = notification.userInfo,
           let keyboardEndRect = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? AnyObject)?.cgRectValue,
           let hostView = hostView,
           let textAnnotation = editingAnnotation as? TextAnnotationViewModel
        {
            // Transform the keyboard's frame into host view's coordinate system
            let keyboardEndRectInHostView = hostView.convert(keyboardEndRect, from: view.window)
            // Get the text annotation frame in host view's coordinate system
            let textAnnotationFrame = hostView.convert(textAnnotation.viewFrame, from: view)
            // Keyboard overlap over the text annotation frame
            let keyboardOverlap = textAnnotationFrame.maxY - keyboardEndRectInHostView.origin.y
            if keyboardOverlap > 0 {
                // adjust the scroll view content offset, add 16 pixels of gap to have some space
                // between annotation and keyboard
                scrollViewContentOffsetBeforeKeyboardAdjustment = hostView.scrollView.contentOffset
                hostView.scrollView.contentOffset.y += keyboardOverlap + 16
            }
            // observe the frame to adjust the content offset if the new line of text is obscured by the keyboard
            textAnnotationFrameObservation = textAnnotation.observe(\.viewFrame) { [weak self] _, _ in
                guard let self = self else { return }
                let textAnnotationFrame = hostView.convert(textAnnotation.viewFrame, from: self.view)
                let keyboardOverlap = textAnnotationFrame.maxY - keyboardEndRectInHostView.origin.y
                if keyboardOverlap > 0 {
                    hostView.scrollView.contentOffset.y += keyboardOverlap + 16
                }
            }
        }
    }

    /// Reset textView constraints when the keyboard hides
    @objc func keyboardWillHide(notification _: NSNotification) {
        textAnnotationFrameObservation?.invalidate()
        textAnnotationFrameObservation = nil
        guard let hostView = hostView,
              let scrollViewContentOffsetBeforeKeyboardAdjustment = scrollViewContentOffsetBeforeKeyboardAdjustment
        else { return }
        hostView.scrollView.contentOffset = scrollViewContentOffsetBeforeKeyboardAdjustment
        self.scrollViewContentOffsetBeforeKeyboardAdjustment = nil
    }
}
