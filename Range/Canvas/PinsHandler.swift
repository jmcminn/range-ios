import CoreLocation
import MapboxMaps
import OSLog
import RealmSwift
import SnapKit
import Turf
import UIKit

/// Handles display of photo marker pins in the main view.
class PinsHandler {
    unowned let model: ProjectModel
    unowned let canvasContainer: CanvasContainerViewController

    /// Token for notifications about changes in the canvas geometries
    private var geometriesNotificationToken: NotificationToken?

    /// selected pin id or nil if nothing is selected
    var selectedPinId: String?

    /// id of registered delegate
    private var canvasDelegateId: UUID?

    /// id used for annotations manager, layer, etc...
    private let annotationsId = "pins"

    /// - Parameters:
    ///   - model:              model to read the pins from
    ///   - canvasContainer:    handler will add pins to this canvas
    init(model: ProjectModel, canvasContainer: CanvasContainerViewController) {
        self.model = model
        self.canvasContainer = canvasContainer
    }

    deinit {
        // remove the pins annotations
        canvasContainer.annotationsMapView.annotations.removeAnnotationManager(withId: annotationsId)
    }

    func start() {
        loadAndDisplayPins()
        canvasDelegateId = canvasContainer.pdfCanvasViewController.addDelegate(self)
    }

    func stop() {
        if let id = canvasDelegateId {
            canvasContainer.pdfCanvasViewController.removeDelegate(id: id)
        }
        geometriesNotificationToken?.invalidate()
        canvasContainer.annotationsMapView.annotations.removeAnnotationManager(withId: annotationsId)
    }
}

/// Handling of display pins from "database" as mapbox annotations
/// - loading of geometries from the "database" and converting to mapbox annotations
/// - converting geometries to pin annotations
/// - updating annotations on pin selection (so unselected pins have reduced opacity)
///
/// #Reference
/// [Mapbox annotations](https://docs.mapbox.com/ios/maps/guides/annotations/annotations/)
extension PinsHandler {
    /// observe the geometries and reload pins when the change is observed
    private func loadAndDisplayPins() {
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
                case let .update(geometries, deletions, insertions, modifications):
                    self.pinsAnnotationManager.annotations = updateArray(
                        self.pinsAnnotationManager.annotations,
                        from: geometries, deletions: deletions,
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
        var pin = PointAnnotation(id: geometry.id, point: point)
        pin.userInfo = [
            "hasUncompletedComments": geometry.hasUncompletedComments,
            "uploadsCount": geometry.uploadsCount,
        ]
        setPinSelection(&pin)
        return pin
    }

    /// Updates the visuals of currently presented pins based on `self.selectedPinId`
    private func updatePinSelection() {
        pinsAnnotationManager.annotations = pinsAnnotationManager.annotations.map { pin in
            var updatedPin = pin
            setPinSelection(&updatedPin)
            return updatedPin
        }
    }

    /// Update opacity and symbol order for pins based on the selection state.
    private func setPinSelection(_ pin: inout PointAnnotation) {
        guard let uploadsCount = pin.userInfo?["uploadsCount"] as? Int else { return }
        guard let hasUncompletedComments = pin.userInfo?["hasUncompletedComments"] as? Bool else { return }
        if pin.id == selectedPinId {
            // show selected above non selected
            pin.symbolSortKey = 2
            // TODO: marker.selected.badge when we support request for upload update
            pin.iconImage = hasUncompletedComments
                ? "marker.selected.note"
                : numberedImageName("marker.selected.", uploadsCount)
            pin.iconAnchor = .bottom
            pin.iconOffset = [0, 4]
            pin.iconOpacity = 1
        } else {
            pin.symbolSortKey = 1
            pin.iconImage = hasUncompletedComments ? "marker.note" : numberedImageName("marker.", uploadsCount)
            pin.iconAnchor = .center
            let nothingSelected = selectedPinId == nil
            // only reduce opacity if some pin is selected but not this one, if nothing is selected
            // then all pins are fully opaque
            pin.iconOpacity = nothingSelected ? 1 : 0.5
        }
    }

    /// given base name and number produces full name <base><number> for numbers 0..8 and <base>9+ for numbers >= 9
    private func numberedImageName(_ base: String, _ number: Int) -> String {
        base + (number < 9 ? String(number) : "9+")
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
                .flatMap { [
                    numberedImageName("marker.", $0),
                    numberedImageName("marker.selected.", $0),
                    numberedImageName("marker.selected.badge.", $0),
                ] }
                .forEach(addImage)

            ["marker.note", "marker.selected.note"].forEach(addImage)

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
extension PinsHandler {
    /// Searches for pin at given map view coordinates and selects *any* found one
    /// - Parameters:
    ///     - point: search for pin at given map view coordinates
    ///     - completion: callback to be called with the resulting pin
    private func findPin(at point: CGPoint, completion: @escaping (SelectedPin?) -> Void) {
        canvasContainer.annotationsMapView.mapboxMap.queryRenderedFeatures(
            at: point,
            options: RenderedQueryOptions(layerIds: [annotationsId], filter: nil)
        ) { result in
            // take any of the selected features with "pins" source
            guard case let .success(queriedFeatures) = result else { completion(nil); return }
            guard let feature = queriedFeatures.first?.feature else { completion(nil); return }
            completion(SelectedPin(fromFeature: feature))
        }
    }
}

/// Canvas user interactions handling
extension PinsHandler: CanvasViewControllerDelegate {
    func canvasCameraChanged(reason _: CanvasCameraChangeReason) {}

    /// Searches for pin at given map view coordinates and selects *any* found one
    /// If any pin is selected the canvas animates to center on it.
    func canvasTapRecognized(at point: CGPoint) {
        findPin(at: point) { pin in
            if let pin = pin {
                // check if a pin different that currently selectedPin was tapped
                if pin.id != self.selectedPinId {
                    self.selectedPinId = pin.id
                    self.updatePinSelection()
                    self.canvasContainer.pdfCanvasViewController.animatePanAndZoom(
                        cameraCenter: pin.point.coordinates,
                        mapboxZoom: self.canvasContainer.annotationsMapView.mapboxMap.cameraState.zoom
                    )
                }
            } else {
                // unselect if tapped outside of the pin
                self.selectedPinId = nil
                self.updatePinSelection()
            }
        }
    }
}
