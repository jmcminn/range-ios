import CoreLocation
import MapboxMaps
import OSLog
import RealmSwift
import SnapKit
import Turf
import UIKit

/// Selected pin information, instantiated from a Turf Feature or a Mapbox PointAnnotation
struct SelectedPin {
    let id: String
    let point: Point

    init?(fromFeature: Turf.Feature?) {
        guard let feature = fromFeature else {
            return nil
        }
        guard case let .string(featureId) = feature.identifier else { return nil }
        guard case let .point(point) = feature.geometry?.geometry else { return nil }
        id = featureId
        self.point = point
    }

    init?(fromPointAnnotation: PointAnnotation?) {
        guard let pointAnnotation = fromPointAnnotation else {
            return nil
        }
        id = pointAnnotation.id
        point = pointAnnotation.point
    }
}

/// Handles the pins when adding a photo annotation
class AddPhotoPinsHandler {
    unowned let model: ProjectModel
    unowned let canvasContainer: CanvasContainerViewController
    let image: UIImage

    // Initialize Impact Feedback Generator
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    /// Token for notifications about changes in the canvas geometries
    private var geometriesNotificationToken: NotificationToken?

    /// Defines the size of the rectangle used for searching pins near to the photo pin (or screen center)
    private let pinsSearchRectSize = 30.0

    /// The rectangle used for searching pins near to the photo pin (or screen center)
    private lazy var pinsSearchRect = CGRect(
        x: canvasContainer.annotationsMapView.center.x - pinsSearchRectSize / 2.0,
        y: canvasContainer.annotationsMapView.center.y - pinsSearchRectSize / 2.0,
        width: pinsSearchRectSize,
        height: pinsSearchRectSize
    )

    /// whether the pins have loaded at least once (used to initiate the selectedPin with the ``lastPhotoPinId``)
    private var pinsLoadedInitially = false

    /// selected pin or nil if nothing is selected and we're showing the `photoPin`
    var selectedPin: SelectedPin?

    /// Notifies about change in selected pin. provides the geometry id
    var onSelectedPinChange: ((String?) -> Void)?

    /// the pin displaying a photo thumb - used for selecting a new location for the image
    private var photoPinView: UIView?

    /// tooltip shown for a currently selected pin
    private var selectedPinTooltip: MapTooltipView?
    /// tooltip shown for photoPinView
    private var photoPinTooltip: MapTooltipView?

    /// id of registered delegate
    private var canvasDelegateId: UUID?

    /// id used for annotations manager, layer, etc...
    private let annotationsId = "addPhotoPins"

    /// - Parameters:
    ///   - model:              model to read the pins from
    ///   - canvasContainer:    handler will add pins to this canvas
    ///   - image:              image to be displayed on the new photo pin
    init(model: ProjectModel, canvasContainer: CanvasContainerViewController, image: UIImage) {
        self.model = model
        self.canvasContainer = canvasContainer
        self.image = image
        feedbackGenerator.prepare()
    }

    deinit {
        // remove the pins annotations
        canvasContainer.annotationsMapView.annotations.removeAnnotationManager(withId: annotationsId)
    }

    func start() {
        installPhotoPinView()
        loadAndDisplayPins(onInitialLoad: { [weak self] in
            // on first load we need to see if there's a pin matching lastPhotoPinId
            self?.selectInitialPin()
        })
        canvasDelegateId = canvasContainer.pdfCanvasViewController.addDelegate(self)
    }

    func stop() {
        if let id = canvasDelegateId {
            canvasContainer.pdfCanvasViewController.removeDelegate(id: id)
        }
        geometriesNotificationToken?.invalidate()
        photoPinView?.removeFromSuperview()
        hideTooltip()
        canvasContainer.annotationsMapView.annotations.removeAnnotationManager(withId: annotationsId)
    }

    /// Checks if one of initially loaded pins matches ``lastPhotoPinId``, if so selects and animates to it.
    /// Otherwise show photo pin in the center of the screen
    private func selectInitialPin() {
        if let lastPhotoPin = SelectedPin(
            fromPointAnnotation: pinsAnnotationManager.annotations
                .first(where: { $0.id == UserDefaults.lastPhotoPinId })
        ) {
            setSelectedPin(lastPhotoPin)
            canvasContainer.pdfCanvasViewController.animatePanAndZoom(
                cameraCenter: lastPhotoPin.point.coordinates,
                mapboxZoom: canvasContainer.annotationsMapView.mapboxMap.cameraState.zoom
            )
        }
        updatePinSelection()
        updatePhotoPinVisibility()
        if selectedPin != nil {
            showSelectedPinTooltip()
        } else {
            showPhotoPinTooltip()
        }
    }

    /// set selected pin, update the pins and notify about the change
    func setSelectedPin(_ pin: SelectedPin?) {
        selectedPin = pin
        onSelectedPinChange?(pin?.id)
        updatePinSelection()
        updatePinSelection()
        updatePhotoPinVisibility()
    }
}

/// Handling of tooltips for the pins.
/// There are 2 kinds of tooltips
/// 1. tooltip for mapbox pink pins that are displayed as view annotations (https://docs.mapbox.com/ios/maps/guides/annotations/view-annotations/)
///      They are added as mapbox view annotations because they need to follow the pins when the canvas is panned.
/// 2. tooltip for photo pin - added as a native view because it needs to stay center over the photo pin view
extension AddPhotoPinsHandler {
    /// Hide tooltip if any presented (either feature or photo tooltip)
    private func hideTooltip() {
        if let tooltip = selectedPinTooltip {
            canvasContainer.annotationsMapView.viewAnnotations.remove(tooltip)
            selectedPinTooltip = nil
        }
        if let tooltip = photoPinTooltip {
            tooltip.removeFromSuperview()
            photoPinTooltip = nil
        }
    }

    /// Shows the tooltip for the selected pin using mapbox view annotations.
    private func showSelectedPinTooltip() {
        hideTooltip()
        guard let pin = selectedPin else { return }

        let tooltip = MapTooltipView(text:
            pin.id == UserDefaults.lastPhotoPinId ? "Use last location" : "Use this location")
        let fittingSize = CGSize(
            width: canvasContainer.annotationsMapView.frame.size.width,
            height: UIView.layoutFittingExpandedSize.height
        )
        let tooltipSize = tooltip.systemLayoutSizeFitting(fittingSize)
        let tooltipOptions = ViewAnnotationOptions(
            geometry: pin.point,
            width: tooltipSize.width.rounded(.up), // with no rounding the text was truncated...
            height: tooltipSize.height.rounded(.up),
            allowOverlap: true,
            anchor: .bottom,
            offsetY: 53
        )
        tooltip.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        UIView.animate(withDuration: 0.2) {
            tooltip.transform = CGAffineTransform(scaleX: 1, y: 1)
        }
        try? canvasContainer.annotationsMapView.viewAnnotations.add(tooltip, options: tooltipOptions)
        selectedPinTooltip = tooltip
    }

    /// Shows the tooltip for the photo pin as a native view added to the canvasContainer content
    private func showPhotoPinTooltip() {
        hideTooltip()
        guard photoPinTooltip == nil else { return } // already shown
        let tooltip = MapTooltipView(text: "New location")
        canvasContainer.content.addSubview(tooltip)
        tooltip.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            // center pin tip on the screen center (the asset has insets defined to ignore shadow)
            make.bottom.equalTo(canvasContainer.content.snp.centerY).offset(-68)
        }
        tooltip.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        UIView.animate(withDuration: 0.2) {
            tooltip.transform = CGAffineTransform(scaleX: 1, y: 1)
        }
        photoPinTooltip = tooltip
    }
}

/// Handling of photo pin which is a special pin that is displayed as a native view in the center of the screen.
/// It acts a pointer for selecting a new pin coordinates by panning and zooming the canvas)
extension AddPhotoPinsHandler {
    /// This creates photo pin view (if not created yet) and adds to canvas content.
    private func installPhotoPinView() {
        guard photoPinView == nil else { return }

        let pin = PhotoPin(image: image)
        canvasContainer.content.addSubview(pin)
        pin.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        pin.isHidden = true
        photoPinView = pin
    }

    /// Animates showing or hiding the photo pin based on currently selectedPin (if no pin selected then show the photo pin)
    private func updatePhotoPinVisibility() {
        if selectedPin != nil {
            // pink pin selected, animate out the photo pin
            UIView.animate(withDuration: 0.2) {
                self.photoPinView?.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            } completion: { _ in
                self.photoPinView?.isHidden = self.selectedPin != nil
            }
        } else {
            // no pink pin selected, animate in the photo pin
            photoPinView?.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            photoPinView?.isHidden = selectedPin != nil
            UIView.animate(withDuration: 0.2) {
                self.photoPinView?.transform = CGAffineTransform(scaleX: 1, y: 1)
            }
        }
    }
}

/// Handling of display pins from "database" as mapbox annotations
/// - loading of geometries from the "database" and converting to mapbox annotations
/// - converting geometries to pin annotations
/// - updating annotations on pin selection (so unselected pins have reduced opacity)
///
/// #Reference
/// [Mapbox annotations](https://docs.mapbox.com/ios/maps/guides/annotations/annotations/)
extension AddPhotoPinsHandler {
    /// observe the geometries and reload pins when the change is observed
    ///  - Parameters:
    ///         - onInitialLoad: callback called only once when the pins are initially loaded
    private func loadAndDisplayPins(onInitialLoad: @escaping () -> Void) {
        geometriesNotificationToken = canvasContainer.pdfCanvasViewController.pdfCanvas.geometries
            .where { $0.placeholder == false &&
                $0.annotationType == .photoMarker &&
                // has at least 1 collaboration (have > 0 features that have > 0 collaborations)
                ($0.features.collaborations.count > 0).count > 0
            }
            .observe { [weak self] changes in
                guard let self = self else { return }
                switch changes {
                case let .initial(geometries):
                    self.pinsAnnotationManager.annotations = Array(geometries.compactMap(self.convertGeometryToPin))
                    self.pinsLoadedInitially = true
                    onInitialLoad()
                case let .update(geometries, deletions, insertions, modifications):
                    self.pinsAnnotationManager.annotations = updateArray(
                        self.pinsAnnotationManager.annotations,
                        from: geometries,
                        deletions: deletions,
                        insertions: insertions,
                        modifications: modifications,
                        convert: self.convertGeometryToPin
                    )
                case let .error(error):
                    Logger.model.error("observing geometries failed: \(error.localizedDescription, privacy: .public)")
                }
            }
    }

    /// Converts the geometry to a PointAnnotation for presenting the pin.
    private func convertGeometryToPin(geometry: Geometry) -> PointAnnotation? {
        guard case let .point(point) = geometry.geometry else {
            // not a point geometry, ignore
            return nil
        }
        let selected = geometry.id == selectedPin?.id
        var pin = PointAnnotation(id: geometry.id, point: point)
        pin.iconImage = numberedImageName("marker.selected.", geometry.uploadsCount)
        pin.iconAnchor = .bottom
        pin.iconOffset = [0, 4]
        setPin(&pin, selected: selected)
        return pin
    }

    /// Updates the visuals of currently presented pins based on `self.selectedPinId`
    private func updatePinSelection() {
        pinsAnnotationManager.annotations = pinsAnnotationManager.annotations.map { pin in
            var updatedPin = pin
            let selected = pin.id == selectedPin?.id
            setPin(&updatedPin, selected: selected)
            return updatedPin
        }
    }

    /// Update opacity and symbol order for pins based on the selection state.
    private func setPin(_ pin: inout PointAnnotation, selected: Bool) {
        pin.iconOpacity = selected ? 1 : 0.5
        // show selected above non selected
        pin.symbolSortKey = selected ? 2 : 1
    }

    /// Create (if not already created) and return a Mapbox PointAnnotationManager for pins
    private var pinsAnnotationManager: PointAnnotationManager {
        if let annotationManager = canvasContainer.annotationsMapView.annotations
            .annotationManagersById[annotationsId] as? PointAnnotationManager
        {
            return annotationManager
        } else {
            let addImage = canvasContainer.annotationsMapView.mapboxMap.style.addImage(named:)

            // add images for pin to style
            Array(0 ... 9)
                .map { numberedImageName("marker.selected.", $0) }
                .forEach(addImage)

            // create annotation manager
            let annotationManager = canvasContainer.annotationsMapView.annotations
                .makePointAnnotationManager(id: annotationsId)
            // the text is embedded in the image
//            annotationManager.textFont = ["SF Pro Text Semibold"]
            annotationManager.iconAllowOverlap = true
            annotationManager.iconIgnorePlacement = true
            return annotationManager
        }
    }
}

/// Pin search methods
extension AddPhotoPinsHandler {
    /// Returns the pin closest to the center of the map view. The pin must be within ``pinsSearchRect``
    /// - Parameters:
    ///     -  completion: callback to be called with the result
    private func findPinClosestToCenter(completion: @escaping (SelectedPin?) -> Void) {
        let mapViewCenter = canvasContainer.annotationsMapView.center

        canvasContainer.annotationsMapView.mapboxMap.queryRenderedFeatures(
            in: pinsSearchRect,
            options: RenderedQueryOptions(layerIds: [annotationsId], filter: nil)
        ) { result in
            guard case let .success(queriedFeatures) = result else {
                completion(nil)
                return
            }
            let closestPin = queriedFeatures
                .filter { $0.source == self.annotationsId }
                .compactMap { SelectedPin(fromFeature: $0.feature) }
                .filter {
                    // only points in the search rectangle
                    self.pinsSearchRect
                        .contains(self.canvasContainer.annotationsMapView.mapboxMap.point(for: $0.point.coordinates))
                }
                .sorted {
                    // find closest to the center (so closest to the photo pin)
                    let point0 = self.canvasContainer.annotationsMapView.mapboxMap.point(for: $0.point.coordinates)
                    let point1 = self.canvasContainer.annotationsMapView.mapboxMap.point(for: $1.point.coordinates)

                    return CGPointDistanceSquared(from: mapViewCenter, to: point0) <
                        CGPointDistanceSquared(from: mapViewCenter, to: point1)
                }
                .first
            completion(closestPin)
        }
    }

    /// Searches for pin at given map view coordinates and selects *any* found one
    /// - Parameters:
    ///     - point: search for pin at given map view coordinates
    ///     - completion: callback to be called with the result
    private func findPin(at point: CGPoint, completion: @escaping (SelectedPin?) -> Void) {
        canvasContainer.annotationsMapView.mapboxMap.queryRenderedFeatures(
            at: point,
            options: RenderedQueryOptions(layerIds: [annotationsId], filter: nil)
        ) { result in
            // take any of the selected features with "pins" source
            guard case let .success(queriedFeatures) = result else { return }
            guard let feature = queriedFeatures.first?.feature else { return }
            completion(SelectedPin(fromFeature: feature))
        }
    }
}

/// Canvas user interactions handling
extension AddPhotoPinsHandler: CanvasViewControllerDelegate {
    /// Reset selected pin if user panned the map
    func canvasCameraChanged(reason: CanvasCameraChangeReason) {
        if reason == .pan || reason == .zoom {
            hideTooltip()
            findPinClosestToCenter { pin in
                // either select the closest feature or deselect if no feature found
                if self.selectedPin?.id != pin?.id {
                    self.feedbackGenerator.impactOccurred()
                    self.feedbackGenerator.prepare()
                    self.setSelectedPin(pin)
                }
            }
        } else if reason == .panEnd {
            // show the tooltip after the pan gesture has ended
            if let selectedPin = selectedPin {
                showSelectedPinTooltip()
                if DebugSettings().centerCanvasOnPinSnap {
                    canvasContainer.pdfCanvasViewController.animatePanAndZoom(
                        cameraCenter: selectedPin.point.coordinates,
                        mapboxZoom: canvasContainer.annotationsMapView.mapboxMap.cameraState.zoom
                    )
                }
            } else {
                showPhotoPinTooltip()
            }
        }
    }

    /// Searches for pin at given map view coordinates and selects *any* found one
    /// If any pin is selected the canvas animates to center on it.
    func canvasTapRecognized(at point: CGPoint) {
        findPin(at: point) { pin in
            // check if a pin different that currently selectedPin was tapped
            guard let pin = pin, pin.id != self.selectedPin?.id else { return }
            if DebugSettings().hapticFeedbackOnPinTapSelection {
                self.feedbackGenerator.impactOccurred()
                self.feedbackGenerator.prepare()
            }
            self.hideTooltip()
            self.setSelectedPin(pin)
            self.canvasContainer.pdfCanvasViewController.animatePanAndZoom(
                cameraCenter: pin.point.coordinates,
                mapboxZoom: self.canvasContainer.annotationsMapView.mapboxMap.cameraState.zoom
            )
            self.showSelectedPinTooltip()
        }
    }
}
