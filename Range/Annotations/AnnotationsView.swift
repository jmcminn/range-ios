import Foundation
import OrderedCollections
import UIKit

/// Represent annotations on 1 photo
class AnnotationsView: NSObject {
    /// view hosting all the annotation views
    let view = UIView()

    // TODO: 1290 is this needed here?
    let viewModel: AnnotationsViewModel

    private weak var hostView: FullscreenImageGalleryPageView?

    var scribbleScale: Double = 1.0

    @objc dynamic var selectedAnnotation: ScribbleViewModel?
    /// remember the origin of selected annotation when dragging begins (so it can be translated while dragging)
    var dragAnnotationOrigin: CGPoint?

    /// subview of `view` to which annotations are added
    let annotationsView = UIView()
    /// The view for drawing (on top of annotationsView)
    var currentScribblingView: ScribblingView?

    /// order in this dictionary is the order of annotations rendering, so last is on top
    private var annotations = OrderedDictionary<ScribbleViewModel, UIView>()

    init(hostView: FullscreenImageGalleryPageView, viewModel: AnnotationsViewModel) {
        self.hostView = hostView
        self.viewModel = viewModel
        super.init()
        hostView.scrollView.forwardDelegateInvocations(to: self)
    }

    deinit {
        hostView?.scrollView.cancelForwardingDelegateInvocations(to: self)
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

        view.addSubview(annotationsView)
        annotationsView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        scribbleScale = viewWidth / imageWidth

        // for annotation selection
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewTapped)))

        // for annotation dragging
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGesture))
        panGestureRecognizer.delegate = self
        view.addGestureRecognizer(panGestureRecognizer)
    }

    /// Add a scribble annotation and return its view
    func add(scribbleWithPath path: RangeBezierPath) {
        let scribble = ScribbleViewModel(scale: scribbleScale, path: path)
        if let hostView = hostView {
            scribble.zoomScale = hostView.scrollView.zoomScale
        }

        let scribbleView = ScribbleView(viewModel: scribble)

        annotations[scribble] = scribbleView

        annotationsView.addSubview(scribbleView)
        scribbleView.frame = scribble.viewBounds
        setSelected(nil)
    }

    func deleteAnnotation(_ annotation: ScribbleViewModel) {
        if let view = annotations[annotation] {
            view.removeFromSuperview()
        }
        annotations[annotation] = nil
        if annotation == selectedAnnotation {
            setSelected(nil)
        }
    }
}

// MARK: - scribble

extension AnnotationsView {
    func setScribblingEnabled(_ enabled: Bool) {
        guard let hostView = hostView else { return }

        hostView.scrollView.isScrollEnabled = !enabled
        // TODO: 1183 enable when installView called
        if enabled {
            currentScribblingView = ScribblingView(scale: scribbleScale)
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

extension AnnotationsView {
    @objc private func viewTapped(gesture: UIGestureRecognizer) {
        // find tapped annotation
        let location = gesture.location(in: view)
        // strictly contains the tap location
        var tappedAnnotations = annotations.keys.filter { $0.containsTapLocation(location) }
        if tappedAnnotations.isEmpty {
            // fallback to "rough containment"
            tappedAnnotations = annotations.keys.filter { $0.roughlyContainsTapLocation(location) }
        }

        if tappedAnnotations.count == 0 {
            // deselect all
            setSelected(nil)
        } else if tappedAnnotations.count == 1 {
            // select if only one annotation matches
            setSelected(tappedAnnotations[0])
        } else {
            // decide which annotation to select by doing some more exact tap recognition
            // and select the scribble with path closest to tap location (but calculating basing
            // on the points only, so as if they were straight lines, for simplification)
            let distancesToTap = tappedAnnotations.map { $0.path.getSimpleDistanceToPoint(location) }
            let minIndex = zip(distancesToTap.indices, distancesToTap).min(by: { $0.1 < $1.1 })?.0 ?? 0
            let closestAnnotation = tappedAnnotations[minIndex]
            setSelected(closestAnnotation)
        }
    }

    /// select given annotation or deselect if nil
    func setSelected(_ selectedAnnotation: ScribbleViewModel?) {
        self.selectedAnnotation = selectedAnnotation
        for annotation in annotations.keys {
            annotation.selected = annotation == selectedAnnotation
        }
        // the selected annotation should be on top
        if let selectedAnnotation = selectedAnnotation {
            // change the order in annotations dictionary
            if let annotationView = annotations.removeValue(forKey: selectedAnnotation) {
                annotations[selectedAnnotation] = annotationView
                // move the view to the top
                annotationsView.bringSubviewToFront(annotationView)
            }
        }
    }
}

// MARK: - drag annotations

extension AnnotationsView: UIGestureRecognizerDelegate {
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
            annotations[selectedAnnotation]?.frame = selectedAnnotation.viewBounds
        }
    }
}

// MARK: - parent scroll view delegate

extension AnnotationsView: UIScrollViewDelegate {
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        for annotation in annotations.keys {
            annotation.zoomScale = scrollView.zoomScale
        }
    }
}
