import CoreLocation
import Firebase
import FirebaseDatabaseSwift
import MapboxMaps
import SnapKit
import Turf
import UIKit

/// Selected pin information
struct SelectedPin {
    let id: String
    let point: Point

    init?(fromFeature: Feature?) {
        guard let feature = fromFeature else {
            return nil
        }
        guard case let .string(featureId) = feature.identifier else { return nil }
        guard case let .point(point) = feature.geometry?.geometry else { return nil }
        id = featureId
        self.point = point
    }
}

/// Handles the pins when adding a photo annotation
class AddPhotoPinsHandler {
    unowned let canvasContainer: CanvasContainerViewController
    let image: UIImage

    var databaseHandle: DatabaseHandle?

    /// Defines the size of the rectangle used for searching pins near to the photo pin (or screen center)
    let pinsSearchRectSize = 30.0

    /// The rectangle used for searching pins near to the photo pin (or screen center)
    lazy var pinsSearchRect = CGRect(
        x: canvasContainer.annotationsMapView.center.x - pinsSearchRectSize / 2.0,
        y: canvasContainer.annotationsMapView.center.y - pinsSearchRectSize / 2.0,
        width: pinsSearchRectSize,
        height: pinsSearchRectSize
    )

    /// selected pin or nil if nothing is selected and we're showing the `photoPin`
    var selectedPin: SelectedPin?

    /// the pin displaying a photo thumb - used for selecting a new location for the image
    var photoPinView: UIView?

    /// tooltip shown for a currently selected pin
    var selectedPinTooltip: MapTooltipView?
    /// tooltip shown for photoPinView
    var photoPinTooltip: MapTooltipView?

    /// id of registered delegate
    var canvasDelegateId: UUID?

    /// - Parameters:
    ///   - canvasContainer:    handler will add pins to this canvas
    ///   - image:              image to be displayed on the new photo pin
    init(canvasContainer: CanvasContainerViewController, image: UIImage) {
        self.canvasContainer = canvasContainer
        self.image = image
    }

    deinit {
        // remove the pins annotations
        canvasContainer.annotationsMapView.annotations.removeAnnotationManager(withId: "pins")
    }

    func start() {
        showPins()
        canvasDelegateId = canvasContainer.pdfCanvas.addDelegate(self)
        updatePinSelection()
        showPhotoPinTooltip()
    }

    func stop() {
        if let id = canvasDelegateId {
            canvasContainer.pdfCanvas.removeDelegate(id: id)
        }
        if let databaseHandle = databaseHandle {
            Database.database().reference().child("geometryData/geometries").removeObserver(withHandle: databaseHandle)
        }
        photoPinView?.removeFromSuperview()
        hideTooltip()
    }

    /// This creates photo pin view (if not created yet) and adds to canvas content.
    private func installPhotoPinView() {
        guard photoPinView == nil else { return }

        let pin = PhotoPin(image: image)
        canvasContainer.content.addSubview(pin)
        pin.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        photoPinView = pin
    }

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

    /// Shows the tooltip for the selected pin.
    private func showSelectedPinTooltip() {
        hideTooltip()
        guard let point = selectedPin?.point else { return }

        let tooltip = MapTooltipView(text: "Use this location")
        let fittingSize = CGSize(
            width: canvasContainer.annotationsMapView.frame.size.width,
            height: UIView.layoutFittingExpandedSize.height
        )
        let tooltipSize = tooltip.systemLayoutSizeFitting(fittingSize)
        let tooltipOptions = ViewAnnotationOptions(
            geometry: point,
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

    /// Shows the tooltip for the photo pin.
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

    /// observe the geometries and reload pins change is observed
    private func showPins() {
        databaseHandle = Database.database().reference().child("geometryData/geometries").observe(.value) { snapshot in
            let geometries = self.convertGeometriesSnapshotToModel(snapshot: snapshot)
            let pins = geometries.compactMap(self.convertGeometryToPin)
            self.pinsAnnotationManager.annotations = pins
        }
    }

    /// Converts the geometries from firebase format to Range model for Geometry
    private func convertGeometriesSnapshotToModel(snapshot: DataSnapshot) -> [Geometry] {
        snapshot.children.compactMap {
            guard let geometrySnapshot = $0 as? DataSnapshot else { return nil }
            do {
                return try geometrySnapshot.data(as: Geometry.self)
            } catch {
                print("error decoding geometry snapshot: \(error)")
                return nil
            }
        }
    }

    // TODO: for now the value of photo count is hardcoded to 1
    /// Converts the geometry to a PointAnnotation for presenting the pin.
    private func convertGeometryToPin(geometry: Geometry) -> PointAnnotation? {
        guard case let .point(pointGeometry) = geometry.geoJSONGeometry else {
            // not a point geometry, ignore
            return nil
        }
        let selected = geometry.id == selectedPin?.id
        var pin = PointAnnotation(id: geometry.id, coordinate: pointGeometry.position)
        pin.iconImage = "largepin"
        pin.iconAnchor = .bottom
        pin.iconOffset = [0, 4]
        pin.textField = "1"
        pin.textSize = 17
        pin.textOffset = [0, -2.35]
        pin.textColor = StyleColor(.Neutral_01)
        setPin(&pin, selected: selected)
        return pin
    }

    /// Updates the currently presented pins based on `self.selectedPinId`
    private func updatePinSelection() {
        pinsAnnotationManager.annotations = pinsAnnotationManager.annotations.map { pin in
            var updatedPin = pin
            let selected = pin.id == selectedPin?.id
            setPin(&updatedPin, selected: selected)
            return updatedPin
        }
        if selectedPin != nil {
            UIView.animate(withDuration: 0.2) {
                self.photoPinView?.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            } completion: { _ in
                self.photoPinView?.isHidden = self.selectedPin != nil
            }
        } else {
            installPhotoPinView()
            photoPinView?.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            photoPinView?.isHidden = selectedPin != nil
            UIView.animate(withDuration: 0.2) {
                self.photoPinView?.transform = CGAffineTransform(scaleX: 1, y: 1)
            }
        }
    }

    /// Update opacity and symbol order for pins based on the selection state.
    private func setPin(_ pin: inout PointAnnotation, selected: Bool) {
        pin.iconOpacity = selected ? 1 : 0.4
        pin.textOpacity = selected ? 1 : 0.4
        // show selected above non selected
        pin.symbolSortKey = selected ? 2 : 1
    }

    /// Create (if not already created) and return a Mapbox PointAnnotationManager for pins
    private var pinsAnnotationManager: PointAnnotationManager {
        if let annotationManager = canvasContainer.annotationsMapView.annotations
            .annotationManagersById["pins"] as? PointAnnotationManager
        {
            return annotationManager
        } else {
            // add image for pin to style
            // TODO: content
            if let largepinImage = UIImage(named: "largepin") {
                do {
                    try canvasContainer.annotationsMapView.mapboxMap.style.addImage(
                        largepinImage,
                        id: "largepin",
                        stretchX: [],
                        stretchY: []
                    )
                } catch {
                    print("Could not add image to style due to error: \(error)")
                }
            } else {
                print("Couldn't load the largepin image from assets")
            }

            // create annotation manager
            let annotationManager = canvasContainer.annotationsMapView.annotations
                .makePointAnnotationManager(id: "pins")
            annotationManager.textFont = ["SF Pro Text Semibold"]
            annotationManager.iconAllowOverlap = true
            annotationManager.iconIgnorePlacement = true
            return annotationManager
        }
    }
}

/// Handling of user interaction
extension AddPhotoPinsHandler {
    /// Returns the pin closest to the center of the map view. The pin must be within ``pinsSearchRect``
    private func findPinClosestToCenter(completion: @escaping (SelectedPin?) -> Void) {
        let mapViewCenter = canvasContainer.annotationsMapView.center

        canvasContainer.annotationsMapView.mapboxMap.queryRenderedFeatures(
            in: pinsSearchRect,
            options: RenderedQueryOptions(layerIds: ["pins"], filter: nil)
        ) { result in
            guard case let .success(queriedFeatures) = result else {
                completion(nil)
                return
            }
            let closestPin = queriedFeatures
                .filter { $0.source == "pins" }
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
    /// If any pin is selected the canvas animates to center on it.
    private func selectPin(at point: CGPoint) {
        canvasContainer.annotationsMapView.mapboxMap.queryRenderedFeatures(
            at: point,
            options: RenderedQueryOptions(layerIds: ["pins"], filter: nil)
        ) { result in
            // take any of the selected features with "pins" source
            guard case let .success(queriedFeatures) = result else { return }
            guard let feature = queriedFeatures.first?.feature else { return }
            guard let newSelectedPin = SelectedPin(fromFeature: feature) else { return }
            // if it's not currently selected mark it as selected and zoom to it
            if newSelectedPin.id != self.selectedPin?.id {
                self.hideTooltip()
                self.selectedPin = newSelectedPin
                self.updatePinSelection()
                self.canvasContainer.pdfCanvas.animatePanAndZoom(
                    cameraCenter: newSelectedPin.point.coordinates,
                    mapboxZoom: self.canvasContainer.annotationsMapView.mapboxMap.cameraState.zoom
                )
                self.showSelectedPinTooltip()
            }
        }
    }
}

/// Notifications of user interactions
extension AddPhotoPinsHandler: CanvasViewControllerDelegate {
    /// Reset selected pin if user panned the map
    func canvasCameraChanged(reason: CanvasCameraChangeReason) {
        if reason == .pan || reason == .zoom {
            hideTooltip()
            findPinClosestToCenter { pin in
                // either select the closest feature or deselect if no feature found
                if self.selectedPin?.id != pin?.id {
                    self.selectedPin = pin
                    self.updatePinSelection()
                }
            }
        } else if reason == .panEnd {
            // show the tooltip after the pan gesture has ended
            if selectedPin != nil {
                showSelectedPinTooltip()
            } else {
                showPhotoPinTooltip()
            }
        }
    }

    func canvasTapRecognized(at point: CGPoint) {
        selectPin(at: point)
    }
}
