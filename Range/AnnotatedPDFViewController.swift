import CoreLocation
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

    var initialMetersPerPoint: Double = 0.0
    var initialZoom: Double = 0.0

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
        pdfScrollView.bouncesZoom = false
        pdfScrollView.pdfPageScrollViewDelegate = self
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
        // TODO: remove the token or replace with Range one (it's from Rafal's private account)
        ResourceOptionsManager.default.resourceOptions
            .accessToken =
            "pk.eyJ1IjoicmFmYWwtcmFuZ2UiLCJhIjoiY2wwd210eHE5MGJlazNlbXlianYzMmFjMiJ9.6VWS7NDvOV1-ghpaWXITHw"
        let cameraOptions = CameraOptions(center: pdfSource.center, zoom: initialZoom)
        mapView = MapView(
            frame: view.bounds,
            mapInitOptions: MapInitOptions(cameraOptions: cameraOptions)
        )
        mapView.alpha = 0.6
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
        UIView.animate(withDuration: 0.1) {
            self.pdfScrollView.zoomScale = 1
            self.pdfScrollView.contentOffset = .zero
        }
    }

    /// Set mapbox camera center and zoom based on current pdf view contentOffset and zoomScale
    private func syncCameraStateWithPDFView() {
        // The contentOffset is the distance between initial and current top/left pdf corner.
        let contentOffset = pdfScrollView.contentOffset
        let viewCenter = pdfScrollView.center
        let zoomScale = pdfScrollView.zoomScale
        let metersPerPoint = initialMetersPerPoint / zoomScale

        // Distance measured in screen coordinates fro current pdf center on screen to screen center.
        // Grows when moving PDF on screen right
        let xPdfCenterDistanceFromViewCenter = -contentOffset.x - viewCenter.x + viewCenter
            .x * zoomScale
        // grows when moving the PDF on screen down
        let yPdfCenterDistanceFromViewCenter = -contentOffset.y - viewCenter.y + viewCenter
            .y * zoomScale
        // move camera the other direction than the PDF
        let cameraCenter = CLLocationCoordinate2D(
            latitude: pdfSource.center.coordinate(
                at: yPdfCenterDistanceFromViewCenter * metersPerPoint,
                facing: 0
            ).latitude, // up
            longitude: pdfSource.center.coordinate(
                at: xPdfCenterDistanceFromViewCenter * metersPerPoint,
                facing: 270
            ).longitude // left
        )
        let mapboxZoom = zoomConverter.getZoom(forMetersPerPoint: metersPerPoint)
        mapView.mapboxMap.setCamera(to: CameraOptions(center: cameraCenter, zoom: mapboxZoom))
    }
}

extension AnnotatedPDFViewController: PDFPageScrollViewDelegate {
    func scrollViewDidScroll(_: PDFPageScrollView) {
        syncCameraStateWithPDFView()
    }

    func scrollViewDidZoom(_: PDFPageScrollView) {
        syncCameraStateWithPDFView()
    }
}
