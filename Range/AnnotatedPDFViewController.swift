import CoreLocation
import Firebase
import FirebaseDatabaseSwift
@_spi(Restricted) @_spi(Experimental) import MapboxMaps
import PDFKit
import Turf
import UIKit

/**
 Displays background PDF with Mapbox map view on top.
 The mapbox map is receiving the user interactions and controls the PDF zoom/offset
 */
class AnnotatedPDFViewController: UIViewController {
    let maxMapboxZoom = 25.5

    let pdfSource: PDFSource

    let zoomConverter: MapboxZoomConverter

    var mapView: MapView!
    var pdfScrollView: PDFPageScrollView!

    private var initialMetersPerPoint: Double = 0.0
    private var initialZoom: Double = 0.0

    /// when animating the pdf and mapview together, we need to disable the sync of zoom/center between them
    private var animationInProgress = false
    /// display link used for pan/zoom animations
    private var displayLink: DisplayLink?

    var selectedPinId: String?

    /// A default empty style for annotations with path to local glyphs
    var annotationsStyle: String {
        guard let fontsPath = Bundle.main.path(forResource: "fonts", ofType: nil) else {
            print("Couldn't find fonts, Mapbox will be broken")
            return "{}"
        }
        return
            """
            {
            "glyphs": "file://\(fontsPath)/{fontstack}/{range}.pbf"
            }
            """
    }

    init(pdfSource: PDFSource) {
        self.pdfSource = pdfSource
        zoomConverter = MapboxZoomConverter(latitude: pdfSource.center.latitude)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        setupPDFScrollView()

        setupInitialZoomAndZoomLimits()

        setupMapView()

        syncCameraStateWithPDFView()

        setupDebugViews()
    }

    private func setupPDFScrollView() {
        pdfScrollView = PDFPageScrollView(frame: view.bounds, pdfPage: pdfSource.page)
        view.addSubview(pdfScrollView)
        pdfScrollView.scrollsToTop = false // we don't want scroll to top on top bar touch
        pdfScrollView.bouncesZoom = false
        pdfScrollView.pdfPageScrollViewDelegate = self
        pdfScrollView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(didTapView(_:)))
        )
    }

    /// Recognize taps in the pdf view, translate to mapbox view and handle pin taps.
    @objc func didTapView(_ sender: UITapGestureRecognizer) {
        let point = sender.location(in: sender.view)
        guard let pointInMapView = sender.view?.convert(point, to: mapView) else { return }
        mapView.mapboxMap.queryRenderedFeatures(
            at: pointInMapView,
            options: nil
        ) { result in
            // take any of the selected features with "pins" source
            guard case let .success(queriedFeatures) = result else { return }
            guard let queriedFeature = queriedFeatures.first(where: { $0.source == "pins" }) else { return }
            self.selectPin(forFeature: queriedFeature.feature)
        }
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
            animatePanAndZoom(cameraCenter: point.coordinates, mapboxZoom: mapView.cameraState.zoom)
        }
    }

    /// Calculates initial mapbox zoom so the PDFPage fits the screen
    private func setupInitialZoomAndZoomLimits() {
        let pdfSizeInMeters = pdfSource.page.sizeInMeters(forScale: pdfSource.scale)
        let pdfWidthMetersPerPoint = pdfSizeInMeters.width / view.bounds.width
        let pdfHeightMetersPerPoint = pdfSizeInMeters.height / view.bounds.height
        initialMetersPerPoint = max(pdfWidthMetersPerPoint, pdfHeightMetersPerPoint)
        initialZoom = zoomConverter.getZoom(forMetersPerPoint: initialMetersPerPoint)

        // minimum is arbitrarily chosen to allow to view the area of 10x width of pdf
        pdfScrollView.minimumZoomScale = 0.1
        // maximum is added so we don't go above the max mapbox zoom scale
        let minMetersPerPoint = zoomConverter.getMetersPerPoint(forZoom: maxMapboxZoom)
        pdfScrollView.maximumZoomScale = initialMetersPerPoint / minMetersPerPoint
        // Just a big number to allow zooming out
        // TODO: add limit to geographical location the center may reach.
        // This cannot be done by the contentInset as it works in a way dependent on zoom.
        // So the contentSize changes with zoom but this value not, so it would allow for different real world bounds depending on the zoom.
        // So it rather needs to be done on the scroll view level where reaching to far should programmatically bounce back to allowed bounds.
        let pdfInset = 100_000.0
        pdfScrollView.contentInset = UIEdgeInsets(
            top: pdfInset,
            left: pdfInset,
            bottom: pdfInset,
            right: pdfInset
        )
    }

    private func setupMapView() {
        // TODO: it seems that we don't need Mapbox accessToken for annotations
//        ResourceOptionsManager.default.resourceOptions.accessToken =
        mapView = MapView(frame: view.bounds)
        // hack to make the Metal subview of the mapView transparent
        // (Mapbox iOS SDK doesn't expose any official way for making the map view transparent,
        // by default it's black even if there's no layers). The trick is to make
        // the MTKView used by Mapbox non opaque
        mapView.subviews.forEach { subview in
            if subview is MTKView {
                subview.isOpaque = false
            }
        }
        mapView.mapboxMap.loadStyleJSON(annotationsStyle) { result in
            switch result {
            case .success:
                print("style loaded successfully")
            case let .failure(error):
                print("style failed to load: ", error.localizedDescription)
            }
            self.showPins()
        }
        do {
            try mapView.mapboxMap.setCameraBounds(with: CameraBoundsOptions(maxZoom: maxMapboxZoom))
        } catch {
            print("Unexpected error: \(error).")
        }

        mapView.ornaments.options.attributionButton.visibility = .hidden
        mapView.ornaments.options.scaleBar.visibility = .hidden

        mapView.isUserInteractionEnabled = false
        view.addSubview(mapView)
    }

    override func viewWillLayoutSubviews() {
        mapView.frame = view.bounds
    }

    private func setupDebugViews() {
        let resetButton = UIButton()
        resetButton.setTitle("reset", for: .normal)
        resetButton.addTarget(self, action: #selector(resetAction), for: .touchUpInside)
        resetButton.sizeToFit()
        resetButton.backgroundColor = .black.withAlphaComponent(0.5)
        view.addSubview(resetButton)
        resetButton.frame.origin = CGPoint(x: 10, y: 40)
    }

    @objc func resetAction() {
        animatePanAndZoom(contentOffset: .zero, zoomScale: 1)
    }

    /// Animate to given cameraCenter and mapboxZoom.
    private func animatePanAndZoom(cameraCenter: CLLocationCoordinate2D, mapboxZoom: Double) {
        let endContentOffset = AnnotatedPDFViewController.mapboxCenterToScrollViewContentOffset(
            cameraCenter: cameraCenter,
            scrollView: pdfScrollView,
            initialCenter: pdfSource.center,
            initialMetersPerPoint: initialMetersPerPoint
        )
        let endZoomScale = initialMetersPerPoint / zoomConverter.getMetersPerPoint(forZoom: mapboxZoom)
        animatePanAndZoom(contentOffset: endContentOffset, zoomScale: endZoomScale)
    }

    /// Animate to given pdf content offset  and zoom.
    /// To sync PDF and Mapbox we need to "manually" animate the scrollView contentOffset and zoom, so mapbox is synced along the way
    private func animatePanAndZoom(contentOffset endContentOffset: CGPoint, zoomScale endZoomScale: Double) {
        let duration = 0.2

        let startContentOffset = pdfScrollView.contentOffset
        let startZoomScale = pdfScrollView.zoomScale

        // any running animation?
        displayLink?.invalidate()
        animationInProgress = true
        displayLink = DisplayLink(handler: { [unowned self] _, t in
            let progress = min(Double(t) / Double(duration), 1)
            let x: CGFloat = startContentOffset.x + (endContentOffset.x - startContentOffset.x) * progress
            let y: CGFloat = startContentOffset.y + (endContentOffset.y - startContentOffset.y) * progress
            let zoom: CGFloat = startZoomScale + (endZoomScale - startZoomScale) * progress
            self.pdfScrollView.contentOffset = CGPoint(x: x, y: y)
            self.pdfScrollView.zoomScale = zoom
            self.syncCameraStateWithPDFView()
            if t >= duration {
                self.displayLink?.invalidate()
                self.displayLink = nil
                self.animationInProgress = false
            }
        })
    }

    /// Set mapbox camera center and zoom based on current pdf view contentOffset and zoomScale
    private func syncCameraStateWithPDFView() {
        let cameraCenter = AnnotatedPDFViewController.scrollViewStateToMapboxCenter(
            scrollView: pdfScrollView,
            initialCenter: pdfSource.center,
            initialMetersPerPoint: initialMetersPerPoint
        )
        let metersPerPoint = initialMetersPerPoint / pdfScrollView.zoomScale
        let mapboxZoom = zoomConverter.getZoom(forMetersPerPoint: metersPerPoint)
        mapView.mapboxMap.setCamera(to: CameraOptions(center: cameraCenter, zoom: mapboxZoom))
    }

    /// Calculate what should be the camera center for Mapbox so it matches the current pdf scroll view contentOffset and zoom
    private static func scrollViewStateToMapboxCenter(
        scrollView: UIScrollView,
        initialCenter: CLLocationCoordinate2D,
        initialMetersPerPoint: Double
    ) -> CLLocationCoordinate2D {
        // The contentOffset is the distance between initial and current top/left corner of the content.
        let contentOffset = scrollView.contentOffset
        let viewCenter = scrollView.center
        let zoomScale = scrollView.zoomScale
        let metersPerPoint = initialMetersPerPoint / zoomScale

        // Distance measured in screen coordinates fro current pdf center on screen to screen center.
        // Grows when moving PDF on screen right
        let xPdfCenterDistanceFromViewCenter = -contentOffset.x - viewCenter.x + viewCenter
            .x * zoomScale
        // grows when moving the PDF on screen down
        let yPdfCenterDistanceFromViewCenter = -contentOffset.y - viewCenter.y + viewCenter
            .y * zoomScale
        // move camera the other direction than the PDF
        let cameraUp = initialCenter.coordinate(at: yPdfCenterDistanceFromViewCenter * metersPerPoint, facing: 0)
        let cameraLeft = initialCenter.coordinate(at: xPdfCenterDistanceFromViewCenter * metersPerPoint, facing: 270)
        let cameraCenter = CLLocationCoordinate2D(latitude: cameraUp.latitude, longitude: cameraLeft.longitude)
        return cameraCenter
    }

    // calculate what should be the pdf scroll view content offset to match given mapbox camera center (at current zoom level)
    private static func mapboxCenterToScrollViewContentOffset(
        cameraCenter: CLLocationCoordinate2D,
        scrollView: UIScrollView,
        initialCenter: CLLocationCoordinate2D,
        initialMetersPerPoint: Double
    ) -> CGPoint {
        let viewCenter = scrollView.center
        let zoomScale = scrollView.zoomScale
        let metersPerPoint = initialMetersPerPoint / zoomScale

        let xSign: Double = cameraCenter.longitude > initialCenter.longitude ? -1 : 1
        let xCameraCenterDistanceFromInitialCenter = xSign *
            cameraCenter.distance(to: CLLocationCoordinate2D(latitude: cameraCenter.latitude,
                                                             longitude: initialCenter.longitude)) / metersPerPoint
        let ySign: Double = cameraCenter.latitude < initialCenter.latitude ? -1 : 1
        let yCameraCenterDistanceFromInitialCenter = ySign *
            cameraCenter.distance(to: CLLocationCoordinate2D(latitude: initialCenter.latitude,
                                                             longitude: cameraCenter.longitude)) / metersPerPoint

        let xOffset = -(xCameraCenterDistanceFromInitialCenter + viewCenter.x - viewCenter.x * zoomScale)
        let yOffset = -(yCameraCenterDistanceFromInitialCenter + viewCenter.y - viewCenter.y * zoomScale)

        return CGPoint(x: xOffset, y: yOffset)
    }
}

extension AnnotatedPDFViewController: PDFPageScrollViewDelegate {
    func scrollViewDidScroll(_: PDFPageScrollView) {
        // controlled animation syncs the state itself
        if !animationInProgress {
            syncCameraStateWithPDFView()
        }
        // only reset pin if the user is panning (= it's not programmatically started animation)
        if !animationInProgress {
            selectPin(forFeature: nil)
        }
    }

    func scrollViewDidZoom(_: PDFPageScrollView) {
        // controlled animation syncs the state itself
        if !animationInProgress {
            syncCameraStateWithPDFView()
        }
    }
}

// TODO: refactor this class to separate Mapbox (annotations) and allow to switch between
// different modes (like show photo markers, show photo pins for photo location selection, etc)
/// A very draft approach to showing photo pins.
extension AnnotatedPDFViewController {
    /// observe the geometries and reload pins change is observed
    private func showPins() {
        Database.database().reference().child("geometryData/geometries").observe(.value) { snapshot in
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
        if let annotationManager = mapView.annotations.annotationManagersById["pins"] as? PointAnnotationManager {
            return annotationManager
        } else {
            // add image for pin to style
            // TODO: content
            if let largepinImage = UIImage(named: "largepin") {
                do {
                    try mapView.mapboxMap.style.addImage(largepinImage, id: "largepin", stretchX: [], stretchY: [])
                } catch {
                    print("Could not add image to style due to error: \(error)")
                }
            } else {
                print("Couldn't load the largepin image from assets")
            }

            // create annotation manager
            let annotationManager = mapView.annotations.makePointAnnotationManager(id: "pins")
            annotationManager.textFont = ["SF Pro Text Semibold"]
            annotationManager.iconAllowOverlap = true
            annotationManager.iconIgnorePlacement = true
            return annotationManager
        }
    }
}
