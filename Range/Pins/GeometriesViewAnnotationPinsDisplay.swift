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
    private let canvas: PDFCanvas
    unowned let canvasVC: PDFCanvasViewController
    private let selectionEnabled: Bool
    private let deselectOnCanvasTap: Bool
    private let ignoredGeometryId: String?
    private let showArchivedPins: Bool
    private let geometryPinDisplayOptionsProvider: GeometryPinDisplayOptionsProvider

    /// Token for notifications about changes in the canvas geometries
    private var geometriesNotificationToken: NotificationToken?

    /// Whether the pins display is currently started or not (not started yet or stopped)
    private(set) var started: Bool = false

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
        canvas: PDFCanvas,
        canvasViewController: PDFCanvasViewController,
        selectionEnabled: Bool = true,
        deselectOnCanvasTap: Bool,
        ignoredGeometryId: String? = nil,
        showArchivedPins: Bool,
        geometryPinDisplayOptionsProvider: @escaping GeometryPinDisplayOptionsProvider
    ) {
        self.canvas = canvas
        canvasVC = canvasViewController
        self.selectionEnabled = selectionEnabled
        self.deselectOnCanvasTap = deselectOnCanvasTap
        self.ignoredGeometryId = ignoredGeometryId
        self.showArchivedPins = showArchivedPins
        self.geometryPinDisplayOptionsProvider = geometryPinDisplayOptionsProvider
    }

    func start(onInitialLoad: (() -> Void)? = nil) {
        started = true
        loadAndDisplayPins(onInitialLoad: onInitialLoad)
        canvasDelegateId = canvasVC.addDelegate(self)
    }

    func stop() {
        started = false
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
        var geometries = canvas.geometries
            .where { $0.placeholder == false &&
                $0.annotationType == .photoMarker &&
                // has at least 1 collaboration (have > 0 features that have > 0 collaborations)
                ($0.features.collaborations.count > 0).count > 0
            }
        if !showArchivedPins {
            geometries = geometries.where { $0.archivedTimestamp == nil }
        }
        geometriesNotificationToken = geometries
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
        let collaboration = pinView.collaboration
        let selected = pinView.id == selectedPin?.id
        let anythingSelected = selectedPin != nil
        let pinOptions = geometryPinDisplayOptionsProvider(collaboration, selected, anythingSelected)
        // The pinView doesn't animate the image properly when this code is run withing animation block, so disable
        // animations for pinView updates.
        UIView.performWithoutAnimation {
            let newImage = pinOptions.pinImage.image
            let imageSizeChanged: Bool
            if let previousSize = pinView.image?.size, let newSize = newImage?.size, previousSize != newSize {
                imageSizeChanged = true
            } else {
                imageSizeChanged = false
            }
            // if image size has changed for pin, we need to remove it and add again as the views
            // cannot be updated live. The same applies to anchor/offset but currently the only
            // case we have is that selecting/unselecting changes the pin (size) and also anchor/offset
            // so it's enough to check for size change.
            if imageSizeChanged {
                canvasVC.mapView.viewAnnotations.remove(pinView)
            }
            pinView.image = newImage
            pinView.sizeToFit()
            pinView.alpha = pinOptions.alpha
            let options = ViewAnnotationOptions(
                geometry: pinView.point,
                width: pinView.bounds.width,
                height: pinView.bounds.height,
                allowOverlap: true,
                visible: pinView.id != ignoredGeometryId,
                anchor: pinOptions.anchor,
                offsetY: pinOptions.offsetY,
                selected: selected
            )
            do {
                if update, !imageSizeChanged {
                    try canvasVC.mapView.viewAnnotations.update(pinView, options: options)
                } else {
                    try canvasVC.mapView.viewAnnotations.add(pinView, options: options)
                }
            } catch {
                print("error \(update ? "updating" : "adding") view annotation: ", error)
            }
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
        guard selectionEnabled else { return }
        if pinView.id != selectedPin?.id {
            setSelectedPin(PinPoint(fromPinView: pinView))
            canvasVC.animatePanAndZoom(
                cameraCenter: pinView.point.coordinates,
                mapboxZoom: canvasVC.mapView.mapboxMap.cameraState.zoom
            )
        }
    }
}
