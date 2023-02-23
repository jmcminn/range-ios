import CoreLocation
import MapboxMaps
import OSLog
import RealmSwift
import SnapKit
import Turf
import UIKit

/// Handles display of pins for geometries using mapbox annotations.
/// Uses PointAnnotations (not native UIKit views) that are rendered as features in the mapbox map layers
///
/// #Reference
/// [Mapbox annotations](https://docs.mapbox.com/ios/maps/guides/annotations/annotations/)
class GeometriesAnnotationPinsDisplay: GeometriesPinsDisplay {
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

    /// id used for annotations manager, layer, etc...
    private let annotationsId = "pins"

    /// map of geometry id => PointAnnotation for fast lookup
    private var pointAnnotationsById = [String: PointAnnotation]()

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
        canvasVC.mapView.annotations.removeAnnotationManager(withId: annotationsId)
    }

    func pinForGeometryId(_ geometryId: String) -> PinPoint? {
        PinPoint(fromPointAnnotation: pinsAnnotationManager.annotations.first(where: { $0.id == geometryId }))
    }

    func findPin(closestToPoint point: CGPoint, searchSquareSize: CGFloat, completion: @escaping (PinPoint?) -> Void) {
        /// The rectangle used for searching pins, centered at given point with the side size equal to searchSquareSize
        let pinsSearchRect = CGRect(
            x: point.x - searchSquareSize / 2.0,
            y: point.y - searchSquareSize / 2.0,
            width: searchSquareSize,
            height: searchSquareSize
        )
        canvasVC.mapView.mapboxMap.queryRenderedFeatures(
            with: pinsSearchRect,
            options: RenderedQueryOptions(layerIds: [annotationsId], filter: nil)
        ) { result in
            guard case let .success(queriedFeatures) = result else {
                completion(nil)
                return
            }
            let closestPin = queriedFeatures
                .filter { $0.source == self.annotationsId }
                .compactMap { self.convertFeatureToPin($0.feature) }
                .filter {
                    // skip archived pins
                    guard let archived = $0.userInfo?["archived"] as? Bool else { return false }
                    if !self.showArchivedPins, archived {
                        return false
                    }
                    return true
                }
                .compactMap(PinPoint.init(fromPointAnnotation:))
                .filter {
                    // only points in the search rectangle
                    pinsSearchRect.contains(self.canvasVC.mapView.mapboxMap
                        .point(for: $0.point.coordinates))
                }
                .sorted {
                    // find closest to the center (so closest to the photo pin)
                    let point0 = self.canvasVC.mapView.mapboxMap.point(for: $0.point.coordinates)
                    let point1 = self.canvasVC.mapView.mapboxMap.point(for: $1.point.coordinates)

                    return CGPointDistanceSquared(from: point, to: point0) <
                        CGPointDistanceSquared(from: point, to: point1)
                }
                .first
            completion(closestPin)
        }
    }
}

/// Handling of display pins from "database" as mapbox annotations
/// - loading of geometries from the "database" and converting to mapbox annotations
/// - converting geometries to pin annotations
/// - updating annotations on pin selection (so unselected pins have reduced opacity)
///
extension GeometriesAnnotationPinsDisplay {
    /// observe the geometries and reload pins when the change is observed
    private func loadAndDisplayPins(onInitialLoad: (() -> Void)?) {
        geometriesNotificationToken = canvas.geometries
            .where { $0.placeholder == false &&
                $0.annotationType == .photoMarker &&
                // has at least 1 collaboration (have > 0 features that have > 0 collaborations)
                ($0.features.collaborations.count > 0).count > 0
            }
            .observe { [weak self] changes in
                guard let self = self else { return }
                switch changes {
                case let .initial(geometries):
                    self.initiatePointAnnotations(forGeometries: geometries)
                    onInitialLoad?()
                case let .update(geometries, deletions, insertions, modifications):
                    self.updatePointAnnotations(
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
        updatePointAnnotationSelection()
        onSelectedPinChange?(pinPoint)
    }

    private func initiatePointAnnotations(forGeometries geometries: Results<Geometry>) {
        pinsAnnotationManager.annotations = Array(geometries.compactMap(convertGeometryToPin))
        updatePointAnnotationsById()
    }

    private func updatePointAnnotations(
        forGeometries geometries: Results<Geometry>,
        deletions: [Int],
        insertions: [Int],
        modifications: [Int]
    ) {
        pinsAnnotationManager.annotations = updateArray(
            pinsAnnotationManager.annotations,
            from: geometries,
            deletions: deletions,
            insertions: insertions,
            modifications: modifications,
            convert: convertGeometryToPin
        )
        updatePointAnnotationsById()
    }

    /// This function updates the lookup dictionary pointAnnotationsById.
    /// Should be called after every update to pinsAnnotationManager.annotations
    private func updatePointAnnotationsById() {
        pointAnnotationsById =
            Dictionary(uniqueKeysWithValues: zip(pinsAnnotationManager.annotations.map(\.id),
                                                 pinsAnnotationManager.annotations))
    }

    /// Converts the geometry to a PointAnnotation for presenting the pin.
    private func convertGeometryToPin(geometry: Geometry) -> PointAnnotation? {
        guard geometry.id != ignoredGeometryId else {
            // this geometry should be ignored and not displayed
            return nil
        }
        guard let collaboration = geometry.features.first?.collaborations.first else {
            // no collaboration, ignore
            return nil
        }
        guard collaboration.placeholder == false else {
            // collaboration is a placeholder, ignore
            return nil
        }
        guard case let .point(point) = geometry.geometry else {
            // not a point geometry, ignore
            return nil
        }
        var pin = PointAnnotation(id: geometry.id, point: point)
        pin.userInfo = [
            "collaboration": collaboration,
            "archived": geometry.archivedTimestamp != nil,
        ]
        setPointAnnotationSelection(&pin)
        return pin
    }

    private func convertFeatureToPin(_ feature: Turf.Feature) -> PointAnnotation? {
        guard case let .string(featureId) = feature.identifier else { return nil }
        return pointAnnotationsById[featureId]
    }

    /// Updates the visuals of currently presented PointAnnotation pins based on `self.selectedPinId`
    private func updatePointAnnotationSelection() {
        pinsAnnotationManager.annotations = pinsAnnotationManager.annotations.map { pin in
            var updatedPin = pin
            setPointAnnotationSelection(&updatedPin)
            return updatedPin
        }
    }

    /// Update opacity and symbol order for pins based on the selection state.
    private func setPointAnnotationSelection(_ pin: inout PointAnnotation) {
        guard let collaboration = pin.userInfo?["collaboration"] as? Collaboration else { return }
        guard let archived = pin.userInfo?["archived"] as? Bool else { return }
        let selected = pin.id == selectedPin?.id
        let anythingSelected = selectedPin != nil
        let pinOptions = geometryPinDisplayOptionsProvider(collaboration, selected, anythingSelected)
        let pinImage = pinOptions.pinImage
        let visible: Bool
        if !selected, !showArchivedPins {
            // hide the pin if the pins display is configured to not show archived pins and this pin is archived
            // BUT: only if it is not selected. So even if it's archived, still show it if it's selected
            visible = !archived
        } else {
            visible = true
        }
        // show selected above non selected
        pin.symbolSortKey = selected ? 2 : 1
        // add the image to the style
        canvasVC.mapView.mapboxMap.style.addPinImage(pinImage)
        pin.iconImage = pinImage.id
        pin.iconOffset = [0, -pinOptions.offsetY]
        pin.iconAnchor = pinOptions.anchor._asIconAnchor()
        if visible {
            pin.iconOpacity = pinOptions.alpha
        } else {
            pin.iconOpacity = 0
        }
    }

    /// Create (if not already created) and return a Mapbox PointAnnotationManager for pins
    private var pinsAnnotationManager: PointAnnotationManager {
        if let annotationManager = canvasVC.mapView.annotations
            .annotationManagersById[annotationsId] as? PointAnnotationManager
        {
            return annotationManager
        } else {
            // create annotation manager
            let annotationManager = canvasVC.mapView.annotations
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
extension GeometriesAnnotationPinsDisplay {
    /// Searches for pin at given map view coordinates and selects *any* found one
    /// - Parameters:
    ///     - point: search for pin at given map view coordinates
    ///     - completion: callback to be called with the resulting pin
    private func findPin(at point: CGPoint, completion: @escaping (PinPoint?) -> Void) {
        canvasVC.mapView.mapboxMap.queryRenderedFeatures(
            with: point,
            options: RenderedQueryOptions(layerIds: [annotationsId], filter: nil)
        ) { result in
            // TODO: 666 here
            // take any of the selected features with "pins" source
            guard case let .success(queriedFeatures) = result else { completion(nil); return }
            let feature = queriedFeatures
                .compactMap { self.convertFeatureToPin($0.feature) }
                .filter {
                    // skip archived pins
                    guard let archived = $0.userInfo?["archived"] as? Bool else { return false }
                    if !self.showArchivedPins, archived {
                        return false
                    }
                    return true
                }
                .first
                .map(PinPoint.init(fromPointAnnotation:))
            completion(feature ?? nil)
        }
    }
}

/// Canvas user interactions handling
extension GeometriesAnnotationPinsDisplay: CanvasViewControllerDelegate {
    func canvasCameraChanged(reason _: CanvasCameraChangeReason) {}

    /// Searches for pin at given map view coordinates and selects *any* found one
    /// If any pin is selected the canvas animates to center on it.
    /// This will only get triggered when pdf is driving the user interaction for canvas, so when using PointAnnotation (non native views for pins).
    func canvasTapRecognized(at point: CGPoint) {
        guard selectionEnabled else { return }
        findPin(at: point) { pin in
            if let pin = pin {
                // check if a pin different that currently selectedPin was tapped
                if pin.id != self.selectedPin?.id {
                    self.setSelectedPin(pin)
                    self.canvasVC.animatePanAndZoom(
                        cameraCenter: pin.point.coordinates,
                        mapboxZoom: self.canvasVC.mapView.mapboxMap.cameraState.zoom
                    )
                }
            } else {
                // unselect if tapped outside of the pin
                if self.deselectOnCanvasTap {
                    self.setSelectedPin(nil)
                }
            }
        }
    }
}
