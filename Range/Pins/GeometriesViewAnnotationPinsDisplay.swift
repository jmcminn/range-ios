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
    unowned let canvasVC: PDFCanvasViewController
    private let deselectOnCanvasTap: Bool
    private let geometryPinDisplayOptionsProvider: GeometryPinDisplayOptionsProvider

    /// Token for notifications about changes in the canvas geometries
    private var geometriesNotificationToken: NotificationToken?

    /// selected pin point or nil if nothing is selected
    private(set) var selectedPin: PinPoint?

    /// Notifies about change in selected pin.  PinPoint provides the geometry id
    var onSelectedPinChange: ((PinPoint?) -> Void)?

    /// id of registered delegate
    private var canvasDelegateId: UUID?

    /// array of pinViews (for native view annotations) matching the current geometries (optional as creating pin view can fail if
    /// geometry is not a point)
    private var pinViews: [PinView?] = []

    /// - Parameters:
    ///   - canvasViewController:    will add pins to this canvas
    required init(
        canvasViewController: PDFCanvasViewController,
        deselectOnCanvasTap: Bool,
        geometryPinDisplayOptionsProvider: @escaping GeometryPinDisplayOptionsProvider
    ) {
        canvasVC = canvasViewController
        self.deselectOnCanvasTap = deselectOnCanvasTap
        self.geometryPinDisplayOptionsProvider = geometryPinDisplayOptionsProvider
    }

    func start(onInitialLoad: (() -> Void)? = nil) {
        loadAndDisplayPins(onInitialLoad: onInitialLoad)
        canvasDelegateId = canvasVC.addDelegate(self)
    }

    func stop() {
        if let id = canvasDelegateId {
            canvasVC.removeDelegate(id: id)
        }
        geometriesNotificationToken?.invalidate()

        pinViews.forEach {
            if let view = $0 { canvasVC.mapView.viewAnnotations.remove(view) }
        }
    }

    func pinForGeometryId(_ geometryId: String) -> PinPoint? {
        PinPoint(fromPinView: pinViews.compacted().first(where: { $0.id == geometryId }))
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
            pinViews.compacted()
                .filter {
                    // only currently visible
                    !$0.isHidden
                }
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
        geometriesNotificationToken = canvasVC.pdfCanvas.geometries
            .where { $0.placeholder == false &&
                $0.annotationType == .photoMarker &&
                // has at least 1 collaboration (have > 0 features that have > 0 collaborations)
                ($0.features.collaborations.count > 0).count > 0
            }
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
        updatePinViewSelection()
        onSelectedPinChange?(pinPoint)
    }

    /// Create and show initial pin views
    private func initiatePinViews(forGeometries geometries: Results<Geometry>) {
        pinViews = geometries.map {
            let pinView = PinView(geometry: $0)
            pinView?.delegate = self
            return pinView
        }
        pinViews.forEach { displayPinView(pinView: $0) }
    }

    private func updatePinViews(
        forGeometries geometries: Results<Geometry>,
        deletions: [Int],
        insertions: [Int],
        modifications: [Int]
    ) {
        for deletionIndex in deletions.sorted(by: >) {
            // remove the existing element
            guard deletionIndex < pinViews.count else { return }
            if let view = pinViews[deletionIndex] {
                canvasVC.mapView.viewAnnotations.remove(view)
            }
            pinViews.remove(at: deletionIndex)
        }
        for insertionIndex in insertions {
            let pinView = PinView(geometry: geometries[insertionIndex])
            pinView?.delegate = self
            pinViews.insert(pinView, at: insertionIndex)
            displayPinView(pinView: pinView)
        }
        for modificationIndex in modifications {
            guard modificationIndex < pinViews.count else { return }
            pinViews[modificationIndex]?.setGeometry(geometries[modificationIndex])
            displayPinView(pinView: pinViews[modificationIndex], update: true)
        }
    }

    /// Update the PinView for current selection state and add/update in mapbox view annotations
    private func displayPinView(pinView: PinView?, update: Bool = false) {
        guard let pinView = pinView else { return }
        let geometry = pinView.geometry
        let selected = pinView.id == selectedPin?.id
        let anythingSelected = selectedPin != nil
        let pinOptions = geometryPinDisplayOptionsProvider(geometry, selected, anythingSelected)
        pinView.image = UIImage(named: pinOptions.imageName)
        pinView.sizeToFit()
        pinView.alpha = pinOptions.alpha
        let options = ViewAnnotationOptions(
            geometry: pinView.point,
            width: pinView.bounds.width,
            height: pinView.bounds.height,
            allowOverlap: true,
            anchor: pinOptions.anchor,
            offsetY: pinOptions.offsetY,
            selected: selected
        )
        do {
            if update {
                // HACK, mapbox is supposed to bring the `selected=true` views to the front
                // but it doesn't look it's actually always doing it. So the currently selected
                // view is readded to the annotations, so it's the last one and displayed on top
                if selected {
                    canvasVC.mapView.viewAnnotations.remove(pinView)
                    try canvasVC.mapView.viewAnnotations.add(pinView, options: options)
                } else {
                    try canvasVC.mapView.viewAnnotations.update(pinView, options: options)
                }
            } else {
                try canvasVC.mapView.viewAnnotations.add(pinView, options: options)
            }
        } catch {
            print("error \(update ? "updating" : "adding") view annotation: ", error)
        }
    }

    /// Updates the visuals of currently presented PinView pins based on `self.selectedPin`
    private func updatePinViewSelection() {
        pinViews.forEach { pinView in
            guard let pinView = pinView else { return }
            displayPinView(pinView: pinView, update: true)
        }
    }
}

/// User interactions handling
extension GeometriesViewAnnotationPinsDisplay: CanvasViewControllerDelegate, PinViewDelegate {
    func canvasCameraChanged(reason _: CanvasCameraChangeReason) {}

    /// If canvas tapped outside of the pin, deselect the currently selected
    func canvasTapRecognized(at _: CGPoint) {
        if deselectOnCanvasTap {
            // unselect if tapped outside of the pin
            setSelectedPin(nil)
        }
    }

    /// select tapped pin
    func pinViewTapped(_ pinView: PinView) {
        if pinView.id != selectedPin?.id {
            setSelectedPin(PinPoint(fromPinView: pinView))
            canvasVC.animatePanAndZoom(
                cameraCenter: pinView.point.coordinates,
                mapboxZoom: canvasVC.mapView.mapboxMap.cameraState.zoom
            )
        }
    }
}
