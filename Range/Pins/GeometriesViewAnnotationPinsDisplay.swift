import MapboxMaps
import OSLog
import RealmSwift
import SnapKit
import Turf
import UIKit

/// Handles display of pins for geometries using mapbox view annotations (using UIKit views)
///
/// #Reference
/// [Mapbox view annotations](https://docs.mapbox.com/ios/maps/guides/annotations/view-annotations/)
class GeometriesViewAnnotationPinsDisplay: GeometriesPinsDisplay {
    private let canvas: Canvas
    unowned let canvasVC: CanvasViewController
    private let selectionEnabled: Bool
    private let deselectOnCanvasTap: Bool
    private let ignoredGeometryId: String?
    private let canvasFilters: CollaborationFilters
    private let geometryPinDisplayOptionsProvider: GeometryPinDisplayOptionsProvider

    /// Token for notifications about changes in the canvas geometries
    private var geometriesNotificationToken: NotificationToken?

    /// Whether the pins display is currently started or not (not started yet or stopped)
    private(set) var started: Bool = false

    /// selected pin point or nil if nothing is selected
    private(set) var selectedPin: PinPoint?

    /// Notifies about change in selected pin.  PinPoint provides the geometry id
    var onSelectedPinChange: ((PinPoint?) -> Void)?

    /// Notifies about tap on canvas (and not on a pin)
    var onCanvasTap: (() -> Void)?

    /// id of registered delegate
    private var canvasDelegateId: UUID?

    /// array of pinViews (for native view annotations) matching the current geometries (optional as creating pin view can fail if
    /// geometry is not a point)
    private var pinAnnotations: [ViewAnnotation?] = []

    /// - Parameters:
    ///   - canvasViewController:    will add pins to this canvas
    required init(
        canvas: Canvas,
        canvasViewController: CanvasViewController,
        selectionEnabled: Bool = true,
        deselectOnCanvasTap: Bool,
        ignoredGeometryId: String? = nil,
        canvasFilters: CollaborationFilters,
        geometryPinDisplayOptionsProvider: @escaping GeometryPinDisplayOptionsProvider
    ) {
        self.canvas = canvas
        canvasVC = canvasViewController
        self.selectionEnabled = selectionEnabled
        self.deselectOnCanvasTap = deselectOnCanvasTap
        self.ignoredGeometryId = ignoredGeometryId
        self.canvasFilters = canvasFilters
        self.geometryPinDisplayOptionsProvider = geometryPinDisplayOptionsProvider
    }

    func start(onInitialLoad: (() -> Void)? = nil) {
        guard !started else { return }
        started = true
        loadAndDisplayPins(onInitialLoad: onInitialLoad)
        canvasDelegateId = canvasVC.addDelegate(self)

        NotificationCenter.default.addObserver(
            self, selector: #selector(canvasFiltersUpdated),
            name: canvasFilters.updateNotificationName, object: nil
        )
    }

    func stop() {
        guard started else { return }
        started = false
        NotificationCenter.default.removeObserver(self)
        if let id = canvasDelegateId {
            canvasVC.removeDelegate(id: id)
        }
        geometriesNotificationToken?.invalidate()

        pinAnnotations.forEach { $0?.remove() }
    }

    @objc func canvasFiltersUpdated() {
        updatePinAnnotations()
    }

    func pinForGeometryId(_ geometryId: String) -> PinPoint? {
        let pinView = pinAnnotations
            .compactMap { $0?.view as? PinView }
            .first { $0.id == geometryId }
        return PinPoint(fromPinView: pinView)
    }

    func findPin(closestToPoint point: CGPoint, searchSquareSize: CGFloat, completion: @escaping (PinPoint?) -> Void) {
        /// The rectangle used for searching pins, centered at given point with the side size equal to searchSquareSize
        let pinsSearchRect = CGRect(
            x: point.x - searchSquareSize / 2.0,
            y: point.y - searchSquareSize / 2.0,
            width: searchSquareSize,
            height: searchSquareSize
        )

        let pinView: PinView? =
            pinAnnotations.compacted()
                .filter(\.visible)
                .compactMap { $0.view as? PinView }
                .filter {
                    // only the ones with the tip of the pin in the search rect
                    pinsSearchRect.contains(CGPoint(x: $0.frame.midX, y: $0.frame.maxY - 4))
                }
                .sorted {
                    // find closest tip to the center
                    let point0 = CGPoint(x: $0.frame.midX, y: $0.frame.maxY - 4)
                    let point1 = CGPoint(x: $1.frame.midX, y: $1.frame.maxY - 4)

                    return CGPointDistanceSquared(from: point, to: point0) <
                        CGPointDistanceSquared(from: point, to: point1)
                }
                .first
        completion(PinPoint(fromPinView: pinView))
    }
}

/// Handling of display pins from "database" as mapbox annotations
/// - loading of geometries from the "database" and converting to mapbox annotations
/// - converting geometries to pin annotations
/// - updating annotations on pin selection (so unselected pins have reduced opacity)
///
extension GeometriesViewAnnotationPinsDisplay {
    /// observe the geometries and reload pins when the change is observed
    private func loadAndDisplayPins(onInitialLoad: (() -> Void)?) {
        geometriesNotificationToken = canvas.pins
            .observe { [weak self] changes in
                guard let self = self else { return }
                switch changes {
                case let .initial(geometries):
                    self.initiatePinViews(forGeometries: geometries)
                    onInitialLoad?()
                case let .update(geometries, deletions, insertions, modifications):
                    self.updatePinViews(
                        forGeometries: geometries,
                        deletions: deletions,
                        insertions: insertions,
                        modifications: modifications
                    )
                case let .error(error):
                    Logger.model.error("observing geometries failed: \(error.localizedDescription, privacy: .public)")
                }
            }
    }

    /// set selected pin, update the pins and notify about the change
    func setSelectedPin(_ pinPoint: PinPoint?) {
        guard pinPoint?.id != selectedPin?.id else { return }
        selectedPin = pinPoint
        updatePinAnnotations()
        onSelectedPinChange?(pinPoint)
    }

    /// Create and show initial pin views
    private func initiatePinViews(forGeometries geometries: Results<Geometry>) {
        pinAnnotations = geometries
            .map {
                if let pinView = PinView(geometry: $0) {
                    pinView.delegate = self
                    return createPinAnnotation(forPinView: pinView)
                } else {
                    return nil
                }
            }
        pinAnnotations.compacted().forEach { canvasVC.mapView.viewAnnotations.add($0) }
    }

    private func updatePinViews(
        forGeometries geometries: Results<Geometry>,
        deletions: [Int],
        insertions: [Int],
        modifications: [Int]
    ) {
        for deletionIndex in deletions.sorted(by: >) {
            // remove the existing element
            guard deletionIndex < pinAnnotations.count else { return }
            if let annotation = pinAnnotations[deletionIndex] {
                annotation.remove()
            }
            pinAnnotations.remove(at: deletionIndex)
        }
        for insertionIndex in insertions {
            if let pinView = PinView(geometry: geometries[insertionIndex]) {
                pinView.delegate = self
                let annotation = createPinAnnotation(forPinView: pinView)
                pinAnnotations.insert(annotation, at: insertionIndex)
                canvasVC.mapView.viewAnnotations.add(annotation)
            } else {
                pinAnnotations.insert(nil, at: insertionIndex)
            }
        }
        for modificationIndex in modifications {
            guard modificationIndex < pinAnnotations.count else { return }
            if let annotation = pinAnnotations[modificationIndex], let pinView = annotation.view as? PinView {
                pinView.setGeometry(geometries[modificationIndex])
                updatePinAnnotation(annotation)
            }
        }
    }

    /// Creates a new ViewAnnotation with given PinView and configures it using `updateAnnotation`
    private func createPinAnnotation(forPinView pinView: PinView) -> ViewAnnotation {
        let annotation = ViewAnnotation(coordinate: pinView.point.coordinates, view: pinView)
        annotation.allowOverlap = true
        annotation.allowOverlapWithPuck = true
        updatePinAnnotation(annotation)
        return annotation
    }

    /// Updates the ViewAnnotation and PinView properties based on selection, visibility and properties of pin geometry and collaboration
    /// The selected pin is always on top because it has the ViewAnnotation.selected set to true.
    private func updatePinAnnotation(_ annotation: ViewAnnotation) {
        guard let pinView = annotation.view as? PinView else { return }
        let selected = pinView.id == selectedPin?.id
        let anythingSelected = selectedPin != nil
        let pinOptions = geometryPinDisplayOptionsProvider(pinView.collaboration, selected, anythingSelected)
        var visible = pinView.id != ignoredGeometryId
        if !selected, !canvasFilters.match(pinView.collaboration) {
            // hide the pin if it doesn't match filters
            // BUT: only if it is not selected. So even if its filtered out, still show it if it's selected
            visible = false
        }
        let newImage = pinOptions.pinImage.image
        let imageSizeChanged = if let previousSize = pinView.image?.size,
                                  let newSize = newImage?.size,
                                  previousSize != newSize { true } else { false }
        pinView.image = newImage
        pinView.alpha = pinOptions.alpha
        annotation.selected = selected
        annotation.visible = visible
        annotation.annotatedFeature = .geometry(pinView.point)
        annotation.variableAnchors = [.init(anchor: pinOptions.anchor, offsetY: pinOptions.offsetY)]
        if imageSizeChanged {
            annotation.setNeedsUpdateSize()
        }
    }

    /// Updates the visuals of currently presented PinView pins
    private func updatePinAnnotations() {
        pinAnnotations.compacted().forEach { updatePinAnnotation($0) }
    }
}

/// User interactions handling
extension GeometriesViewAnnotationPinsDisplay: CanvasViewControllerDelegate, PinViewDelegate {
    func canvasCameraChanged(reason _: CanvasCameraChangeReason) {}

    /// If canvas tapped outside of the pin, deselect the currently selected
    func canvasTapRecognized(at _: CGPoint) {
        onCanvasTap?()
        if deselectOnCanvasTap {
            // unselect if tapped outside of the pin
            setSelectedPin(nil)
        }
    }

    /// select tapped pin
    func pinViewTapped(_ pinView: PinView) {
        guard selectionEnabled else { return }
        guard pinView.id != selectedPin?.id else { return }
        setSelectedPin(PinPoint(fromPinView: pinView))
        canvasVC.animatePanAndZoom(
            cameraCenter: pinView.point.coordinates,
            mapboxZoom: canvasVC.mapView.mapboxMap.cameraState.zoom
        )
    }
}
