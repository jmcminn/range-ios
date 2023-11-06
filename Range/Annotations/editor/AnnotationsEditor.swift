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

    /// whether the annotations were updated from the initialAnnotations
    private(set) var annotationsUpdated: Bool = false { didSet {
        NotificationCenter.default.post(name: AnnotationsEditor.AnnotationsUpdatedNotificationName, object: self)
    }}
    /// The name for the notification posted in NotificationCenter when the `annotationsUpdated` changes
    static let AnnotationsUpdatedNotificationName = Notification
        .Name("io.range.App.AnnotationsEditor.AnnotationsUpdated")

    /// view hosting all the annotation views
    let view = UIView()

    /// The scale applied to annotations. See `Annotations.scale` and `AnnotationViewModel.annotationsScale` for
    /// description how/why it is used.
    var annotationsScale: Double = 1.0

    // whether the annotations are installed in the host view and ready to be edited
    @objc dynamic var installed: Bool = false
    @objc dynamic var selectedAnnotation: AnnotationViewModel?
    /// remember the origin of selected annotation when dragging begins (so it can be translated while dragging)
    var dragAnnotationOrigin: CGPoint?

    /// subview of `view` to which annotations are added
    let annotationsContainerView = UIView()
    /// The view for drawing (on top of annotationsView)
    var currentScribblingView: ScribblingView?

    /// order in this dictionary is the order of annotations rendering, so last is on top
    private var annotationViewModels = OrderedDictionary<String, AnnotationViewModel>()
    private var annotationViews = OrderedDictionary<String, UIView>()

    /// Combine listeners for viewModel
    private var subscriptions = Set<AnyCancellable>()

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
            name: ScribbleAnnotation.UpdateNotificationName, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(checkAnnotationsUpdated),
            name: TextAnnotation.UpdateNotificationName, object: nil
        )
    }

    deinit {
        hostView?.scrollView.cancelForwardingDelegateInvocations(to: self)
        for subscription in subscriptions {
            subscription.cancel()
        }
        NotificationCenter.default.removeObserver(self)
    }

    private func subscribeToViewModel() {
        viewModel.$lastPickedScribbleThickness
            .sink { [weak self] in self?.currentScribblingView?.thickness = $0 }
            .store(in: &subscriptions)
        viewModel.$lastPickedScribbleColor
            .sink { [weak self] in self?.currentScribblingView?.color = $0 }
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

        annotationsScale = initialAnnotations?.scale ?? min(imageWidth, imageHeight) / Annotations.referenceViewSize

        // for annotation selection
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewTapped)))

        // for annotation dragging
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGesture))
        panGestureRecognizer.delegate = self
        view.addGestureRecognizer(panGestureRecognizer)

        // show the initial annotations
        if let initialAnnotations = initialAnnotations {
            for annotation in initialAnnotations.annotations {
                // copy so we don't change the initial annotations (the initial values should not be
                // changed as we need them to compare new state vs initial, changing them would also
                // break the "cancel" functionality of the annotations editor)
                switch annotation {
                case let .scribble(scribble): addScribble(scribble.copy() as! ScribbleAnnotation)
                case let .text(text): addText(text.copy() as! TextAnnotation)
                }
            }
        }

        installed = true
    }

    /// Add a scribble annotation and return its view
    func add(scribbleWithPath path: RangeBezierPath) {
        let scribble = ScribbleAnnotation(
            path: path,
            lineWidth: viewModel.lastPickedScribbleThickness.lineWidth * annotationsScale,
            color: viewModel.lastPickedScribbleColor
        )
        addScribble(scribble)
    }

    private func addScribble(_ scribble: ScribbleAnnotation) {
        let scribbleVM = ScribbleAnnotationViewModel(scribble: scribble, annotationsScale: annotationsScale)
        if let hostView = hostView {
            scribbleVM.zoomScale = hostView.scrollView.zoomScale
        }
        let scribbleView = ScribbleAnnotationView(viewModel: scribbleVM)
        addAnnotation(scribbleVM, view: scribbleView)
    }

    func insertTextAnnotation() {
        guard let hostView = hostView else {
            Logger.annotations.error("insertTextAnnotation: hostView not set!")
            return
        }

        let text = ""
        // insert new annotation in the visible center of the screen (to be precise to the left and up,
        // so it's center is in the center)
        let centerOfTheScreenInImagePoint = view.convert(CGPoint(
            x: hostView.frame.midX,
            y: hostView.frame.midY
        ), from: hostView)

        // TODO: 1981 use latest text size instead of 20
        let initialTextAnnotationSize = TextAnnotationViewModel.initialAnnotationSize(
            text: text, fontSize: 20 * annotationsScale, annotationsScale: annotationsScale
        )
        // position is top left of the box centered at the screen center
        let initialPosition = centerOfTheScreenInImagePoint.translate(
            x: -initialTextAnnotationSize.width / 2,
            y: -initialTextAnnotationSize.height / 2
        )
        // TODO: 1981 font size
        let textAnnotation = TextAnnotation(
            text: text,
            position: initialPosition,
            fontSize: 20 * annotationsScale,
            color: viewModel.lastPickedScribbleColor
        )
        addText(textAnnotation)
        guard let textAnnotationVM = annotationViewModels[textAnnotation.id] as? TextAnnotationViewModel else { return }
        setSelected(textAnnotationVM)
        // start editing
        textAnnotationVM.textEditing = true
    }

    private func addText(_ text: TextAnnotation) {
        let textVM = TextAnnotationViewModel(text: text, annotationsScale: annotationsScale)
        if let hostView = hostView {
            textVM.zoomScale = hostView.scrollView.zoomScale
        }
        let textAnnotationView = TextAnnotationView(viewModel: textVM)
        addAnnotation(textVM, view: textAnnotationView)
    }

    private func addAnnotation(_ annotation: AnnotationViewModel, view: UIView) {
        annotationViewModels[annotation.id] = annotation
        annotationViews[annotation.id] = view

        annotationsContainerView.addSubview(view)
        view.frame = annotation.viewBounds
        setSelected(nil)

        checkAnnotationsUpdated()
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
                width: Int(imageWidth),
                height: Int(imageHeight),
                scale: annotationsScale,
                annotationViewModels.values.map(\.annotation)
            )
        }
    }
}

// MARK: - scribble

extension AnnotationsEditor {
    func setScribblingEnabled(_ enabled: Bool) {
        guard let hostView = hostView else { return }

        hostView.scrollView.isScrollEnabled = !enabled
        if enabled {
            currentScribblingView = ScribblingView(
                scale: annotationsScale,
                thickness: viewModel.lastPickedScribbleThickness,
                color: viewModel.lastPickedScribbleColor
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
                make.width.height.equalToSuperview().dividedBy(annotationsScale)
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

// MARK: - selection

extension AnnotationsEditor {
    @objc private func viewTapped(gesture: UIGestureRecognizer) {
        // find tapped annotation
        let location = gesture.location(in: view)
        // strictly contains the tap location
        var tappedAnnotations = annotationViewModels.values.filter { $0.containsTapLocation(location) }
        if tappedAnnotations.isEmpty {
            // fallback to "rough containment"
            tappedAnnotations = annotationViewModels.values.filter { $0.roughlyContainsTapLocation(location) }
        }

        if tappedAnnotations.count == 0 {
            // deselect all
            setSelected(nil)
        } else if tappedAnnotations.count == 1 {
            // select if only one annotation matches
            setSelected(tappedAnnotations[0])
        } else {
            // decide which annotation to select by doing some more exact tap recognition
            // and select the annotation closest to tap location
            let distancesToTap = tappedAnnotations.map { $0.distanceToTapLocation(location) }
            let minIndex = zip(distancesToTap.indices, distancesToTap).min(by: { $0.1 < $1.1 })?.0 ?? 0
            let closestAnnotation = tappedAnnotations[minIndex]
            setSelected(closestAnnotation)
        }
    }

    /// select given annotation or deselect if nil
    func setSelected(_ selectedAnnotation: AnnotationViewModel?) {
        let previousSelectedAnnotation = self.selectedAnnotation

        self.selectedAnnotation = selectedAnnotation

        if previousSelectedAnnotation != selectedAnnotation {
            // unselect the previous one and select new one
            previousSelectedAnnotation?.selected = false
            // stop editing previous text annotation if unselected
            if let previousSelectedAnnotation = previousSelectedAnnotation as? TextAnnotationViewModel {
                previousSelectedAnnotation.textEditing = false
            }
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
                textAnnotation.textEditing = true
            }
        }

        checkAnnotationsUpdated()
    }
}

// MARK: - drag annotations

extension AnnotationsEditor: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        let location = gesture.location(in: gesture.view)
        // if it's a drag of selected annotation then start recognizing this gesture (and block
        // other gestures like drawing or changing the gallery pages)
        if let selectedAnnotation = selectedAnnotation, selectedAnnotation.viewBounds.contains(location) {
            return true
        }
        return false
    }

    @objc private func panGesture(gesture: UIPanGestureRecognizer) {
        guard let selectedAnnotation = selectedAnnotation else { return }

        if gesture.state == .began {
            dragAnnotationOrigin = selectedAnnotation.viewBounds.origin
        }

        if let dragAnnotationOrigin = dragAnnotationOrigin {
            let translation = gesture.translation(in: view)
            selectedAnnotation.setOrigin(translation.addTo(dragAnnotationOrigin))
            annotationViews[selectedAnnotation.id]?.frame = selectedAnnotation.viewBounds
        }
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
