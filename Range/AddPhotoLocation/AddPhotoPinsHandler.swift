import CoreLocation
import Firebase
import FirebaseDatabaseSwift
import MapboxMaps
import SnapKit
import Turf
import UIKit

/// Handles the pins when adding a photo annotation
class AddPhotoPinsHandler {
    unowned let canvasContainer: CanvasContainerViewController
    let image: UIImage

    var databaseHandle: DatabaseHandle?
    /// feature id (geometry id) of the currently selected pin annotation (or nil if nothing is selected and we're showing the `photoPin`)
    var selectedPinId: String?

    /// the pin displaying a photo thumb - used for selecting a new location for the image
    var photoPinView: UIView?

    /// tooltip shown for a currently selected pin
    var featureTooltip: MapTooltipView?
    /// tooltip shown for photoPinView
    var photoTooltip: MapTooltipView?

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
        showPhotoTooltip()
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

        let pin = createPhotoPin(fromImage: image)
        canvasContainer.content.addSubview(pin)
        pin.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            // center pin tip on the screen center (the asset has insets defined to ignore shadow)
            make.bottom.equalTo(canvasContainer.content.snp.centerY)
        }
        photoPinView = pin
    }

    /// Selects pin for given feature and center screen on it. If `feature` is nil then unselects the currently selected.
    private func selectPin(forFeature feature: Feature?) {
        if feature == nil {
            // unselect if any selected
            if selectedPinId != nil {
                selectedPinId = nil
                updatePinSelection()
            }
        }
        // select a pin
        guard case let .string(featureId) = feature?.identifier else { return }
        guard case let .point(point) = feature?.geometry?.geometry else { return }
        // if it's not currently selected mark it as selected and zoom to it
        if selectedPinId != featureId {
            selectedPinId = featureId
            updatePinSelection()
            canvasContainer.pdfCanvas.animatePanAndZoom(
                cameraCenter: point.coordinates,
                mapboxZoom: canvasContainer.annotationsMapView.mapboxMap.cameraState.zoom
            )
        }
    }

    /// Hide tooltip if any presented (either feature or photo tooltip)
    private func hideTooltip() {
        if let tooltip = featureTooltip {
            canvasContainer.annotationsMapView.viewAnnotations.remove(tooltip)
            featureTooltip = nil
        }
        if let tooltip = photoTooltip {
            tooltip.removeFromSuperview()
            photoTooltip = nil
        }
    }

    /// Shows the tooltip for given feature.
    private func showFeatureTooltip(forFeature feature: Feature) {
        guard case let .point(point) = feature.geometry?.geometry else { return }

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
        featureTooltip = tooltip
    }

    /// Shows the tooltip for the photo pin.
    private func showPhotoTooltip() {
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
        photoTooltip = tooltip
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
        let selected = geometry.id == selectedPinId
        var pin = PointAnnotation(id: geometry.id, coordinate: pointGeometry.position)
        pin.iconImage = "largepin"
        pin.iconAnchor = .bottom
        pin.iconOffset = [0, 4]
        pin.textField = "1"
        pin.textSize = 17
        pin.textOffset = [0, -2.35]
        pin.textColor = StyleColor(UIColor.Misc_White)
        setPin(&pin, selected: selected)
        return pin
    }

    /// Updates the currently presented pins based on `self.selectedPinId`
    private func updatePinSelection() {
        pinsAnnotationManager.annotations = pinsAnnotationManager.annotations.map { pin in
            var updatedPin = pin
            let selected = pin.id == selectedPinId
            setPin(&updatedPin, selected: selected)
            return updatedPin
        }
        if selectedPinId != nil {
            photoPinView?.isHidden = true
        } else {
            installPhotoPinView()
            photoPinView?.isHidden = false
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

extension AddPhotoPinsHandler: CanvasViewControllerDelegate {
    /// Reset selected pin if user panned the map
    func canvasCameraChanged(reason: CanvasCameraChangeReason) {
        if reason == .pan {
            // only reset pin if the user is panning (= it's not programmatically started animation)
            selectPin(forFeature: nil)
            if featureTooltip != nil {
                hideTooltip()
            }
        } else if reason == .panEnd {
            // show the tooltip for photo pin only after the pan gesture has ended
            if photoTooltip == nil {
                showPhotoTooltip()
            }
        }
    }

    /// Select tapped pin or do nothing if no pin was tapped
    func canvasTapRecognized(at point: CGPoint) {
        canvasContainer.annotationsMapView.mapboxMap.queryRenderedFeatures(at: point) { result in
            // take any of the selected features with "pins" source
            guard case let .success(queriedFeatures) = result else { return }
            guard let queriedFeature = queriedFeatures.first(where: { $0.source == "pins" }) else { return }
            self.selectPin(forFeature: queriedFeature.feature)
            self.hideTooltip()
            self.showFeatureTooltip(forFeature: queriedFeature.feature)
        }
    }
}
