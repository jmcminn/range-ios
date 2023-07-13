import Combine
import Foundation
import OrderedCollections
import UIKit

/// Represent annotations editor for 1 photo
/// Shows the annotation views and handles the gestures
class AnnotationsEditor: NSObject {
    private weak var hostView: FullscreenImageGalleryPageView?
    let viewModel: AnnotationsEditorViewModel

    /// view hosting all the annotation views
    let view = UIView()

    var scribbleScale: Double = 1.0

    // whether the annotations are installed in the host view and ready to be edited
    @objc dynamic var installed: Bool = false
    @objc dynamic var selectedAnnotation: ScribbleViewModel?
    /// remember the origin of selected annotation when dragging begins (so it can be translated while dragging)
    var dragAnnotationOrigin: CGPoint?

    /// subview of `view` to which annotations are added
    let annotationsContainerView = UIView()
    /// The view for drawing (on top of annotationsView)
    var currentScribblingView: ScribblingView?

    /// order in this dictionary is the order of annotations rendering, so last is on top
    private var annotationsViews = OrderedDictionary<ScribbleViewModel, UIView>()

    /// Combine listeners for viewModel
    private var subscriptions = Set<AnyCancellable>()

    init(
        hostView: FullscreenImageGalleryPageView,
        viewModel: AnnotationsEditorViewModel
    ) {
        self.hostView = hostView
        self.viewModel = viewModel
        super.init()
        hostView.scrollView.forwardDelegateInvocations(to: self)
        subscribeToViewModel()
    }

    deinit {
        hostView?.scrollView.cancelForwardingDelegateInvocations(to: self)
        for subscription in subscriptions {
            subscription.cancel()
        }
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
        guard viewWidth > 0, imageWidth > 0 else { return }

        hostView.imageView.addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        view.addSubview(annotationsContainerView)
        annotationsContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        scribbleScale = viewWidth / imageWidth

        // for annotation selection
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewTapped)))

        // for annotation dragging
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGesture))
        panGestureRecognizer.delegate = self
        view.addGestureRecognizer(panGestureRecognizer)

        installed = true
    }

    /// Add a scribble annotation and return its view
    func add(scribbleWithPath path: RangeBezierPath) {
        let scribble = ScribbleAnnotation(
            path: path,
            lineWidth: viewModel.lastPickedScribbleThickness.lineWidth / scribbleScale,
            color: viewModel.lastPickedScribbleColor
        )
        addScribble(scribble)
    }

    private func addScribble(_ scribble: ScribbleAnnotation) {
        let scribbleVM = ScribbleViewModel(scale: scribbleScale, scribble: scribble)
        if let hostView = hostView {
            scribbleVM.zoomScale = hostView.scrollView.zoomScale
        }

        let scribbleView = ScribbleView(viewModel: scribbleVM)

        annotationsViews[scribbleVM] = scribbleView

        annotationsContainerView.addSubview(scribbleView)
        scribbleView.frame = scribbleVM.viewBounds
        setSelected(nil)
    }

    func deleteAnnotation(_ annotation: ScribbleViewModel) {
        if let view = annotationsViews[annotation] {
            view.removeFromSuperview()
        }
        annotationsViews[annotation] = nil
        if annotation == selectedAnnotation {
            setSelected(nil)
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
                scale: scribbleScale,
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
                make.width.height.equalToSuperview().multipliedBy(scribbleScale)
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
        var tappedAnnotations = annotationsViews.keys.filter { $0.containsTapLocation(location) }
        if tappedAnnotations.isEmpty {
            // fallback to "rough containment"
            tappedAnnotations = annotationsViews.keys.filter { $0.roughlyContainsTapLocation(location) }
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
    func setSelected(_ selectedAnnotation: ScribbleViewModel?) {
        self.selectedAnnotation = selectedAnnotation
        for annotation in annotationsViews.keys {
            annotation.selected = annotation == selectedAnnotation
        }
        // the selected annotation should be on top
        if let selectedAnnotation = selectedAnnotation {
            // change the order in annotations dictionary
            if let annotationView = annotationsViews.removeValue(forKey: selectedAnnotation) {
                annotationsViews[selectedAnnotation] = annotationView
                // move the view to the top
                annotationsContainerView.bringSubviewToFront(annotationView)
            }
        }
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
            annotationsViews[selectedAnnotation]?.frame = selectedAnnotation.viewBounds
        }
    }
}

// MARK: - parent scroll view delegate

extension AnnotationsEditor: UIScrollViewDelegate {
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        for annotation in annotationsViews.keys {
            annotation.zoomScale = scrollView.zoomScale
        }
    }
}
