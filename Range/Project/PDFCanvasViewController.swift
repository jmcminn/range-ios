import CoreLocation
@_spi(Restricted) @_spi(Experimental) import MapboxMaps
import OSLog
import PDFKit
import Turf
import UIKit

/// Enum that defines what was the reason of camera change. Used in the canvas delegate to notify about camera changes
enum CanvasCameraChangeReason {
    case programmatic // the change was not directly caused by user gesture but rather by some action that resulted in camera programmatic animation
    case pan // user panned the map interactively
    case zoom // user zoomed the map interactively
    case tap // user tapped (no camera change)
    case panEnd // the pan interaction has ended (together with the decelleration)
    case zoomEnd // the zoom interaction has ended
    case tapEnd // the tap has ended

    /// Construct from Mapbox gesture
    ///   - parameters: gesture - mapbox gesture
    ///   - parameters: end - `true` if this is then end of the gesture
    init(fromGesture gesture: MapboxMaps.GestureType, end: Bool = false) {
        switch gesture {
        case .singleTap:
            self = end ? .tapEnd : .tap
        case .pan:
            self = end ? .panEnd : .pan
        default:
            self = end ? .zoomEnd : .zoom
        }
    }
}

/// Defines the notifications to be received by the currently registered canvas delegate.
protocol CanvasViewControllerDelegate {
    /// Camera has changed with given reason
    func canvasCameraChanged(reason: CanvasCameraChangeReason)
    /// User has tapped at given point (given in the annotations map view coordinates)
    func canvasTapRecognized(at: CGPoint)
}

// possible errors for ProjectModel
enum PDFCanvasViewControllerError: Error {
    case canvasNotFound
    case pdfPageLoadFailed
}

// Error extension to provide localized descriptions of errors
extension PDFCanvasViewControllerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .canvasNotFound:
            return "No canvas found"
        case .pdfPageLoadFailed:
            return "Couldn't load the PDF page"
        }
    }
}

/**
 Displays background PDF with Mapbox map view on top.
 The mapbox map is receiving the user interactions and controls the PDF zoom/offset
 */
class PDFCanvasViewController: UIViewController {
    let maxMapboxZoom = 25.5

    /// Available mechanisms of syncing the center/zoom of the background PDF and mapbox map (annotations)
    enum PDFMapSync {
        // 1. interactions with pdf scroll view are translated to mapbox camera:
        case pdf
        // 2. mapbox camera changes are translated to pdf scroll view zoom/offset:
        case mapCamera // this one is currently not used - trying to switch to the .mapCameraAndAnnotation one
        // 3. mapbox transparent annotation views are used to calculate the zoom/offset
        //    this one relies on the fact that mapbox annotations are lagging behind the gesture (and mapbox camera)
        //    so if we sync background PDF offset with some annotation position it should not lag visually
        //    The solution is to add 2 native annotations that are transparent and big enough so they're always
        //    visible on the map (no matter what zoom level, etc.). They need to be always visible as mapbox
        //    does not update positions for views that are not in the map viewport
        case mapAnnotations
    }

    // Current pdf<->map sync mechanism. Currently set to .mapAnnotations.
    // The other ways of sync are left only for reference and will not be used anymore.
    var pdfMapSync: PDFMapSync = .mapAnnotations {
        didSet { updatePDFMapSync() }
    }

    /// observers for pdf/mapbox views. They're being activated/deactivated when switching who drives the interactions
    private var canvasTapGestureRecognizer: UITapGestureRecognizer?
    private var mapboxCameraChangedObserver: Cancelable?
    // 2 annotation views used for .mapAnnotations pdf<->map sync
    private var topLeftSyncAnnotationView: UIView?
    private var bottomRightSyncAnnotationView: UIView?
    // observe the bottom right sync view
    private var bottomRightSyncAnnotationViewObservation: NSKeyValueObservation?
    // the horizontal distance between topLeft and bottomRight when initially rendered
    private var initialSyncViewsDistance: CGFloat?

    /// For case when mapbox drives the interactions we need to store the current gesture (for example 'pan') to continuously
    /// report panning when the camera changes. (the mapbox gestures delegate only reports start/end of gesture)
    private var currentCameraChangeReason: CanvasCameraChangeReason?

    unowned let model: ProjectModel
    let pdfCanvas: PDFCanvas
    let pdfPage: PDFPage

    let zoomConverter: MapboxZoomConverter

    var mapView: MapView!
    var pdfScrollView: PDFPageScrollView!

    private var initialMetersPerPoint: Double = 0.0
    private var initialZoom: Double = 0.0

    /// when animating the pdf and mapview together, we need to disable the sync of zoom/center between them
    private var programmaticAnimationInProgress = false
    /// display link used for pan/zoom animations
    private var displayLink: DisplayLink?

    /// dictionary of delegates stored per id
    private var delegates: [UUID: CanvasViewControllerDelegate] = [:]

    /// A default empty style for annotations with path to local glyphs
    var annotationsStyle: String {
        guard let fontsPath = Bundle.main.path(forResource: "fonts", ofType: nil) else {
            Logger.assets.fault("Couldn't find fonts, Mapbox will be broken")
            return "{}"
        }
        return
            """
            {
            "glyphs": "file://\(fontsPath)/{fontstack}/{range}.pbf"
            }
            """
    }

    init(model: ProjectModel) throws {
        guard let pdfCanvas = model.mainRealm.object(
            ofType: PDFCanvas.self,
            forPrimaryKey: model.demoCanvas.id
        ) else {
            throw PDFCanvasViewControllerError.canvasNotFound
        }
        self.model = model
        self.pdfCanvas = pdfCanvas
        pdfPage = try PDFCanvasViewController.loadPDFPage(pdfCanvas: model.demoCanvas)

        zoomConverter = MapboxZoomConverter(latitude: model.projectSummary.center.latitude)
        super.init(nibName: nil, bundle: nil)
    }

    // TODO: for now it is assumed that url is just a file name from the app bundle
    /// Loads pdf page for given canvas or throws if cannot load.
    fileprivate static func loadPDFPage(pdfCanvas: DemoCanvas) throws -> PDFPage {
        guard
            let documentUrl = Bundle.main.url(
                forResource: pdfCanvas.localFileName,
                withExtension: nil
            ),
            let document = PDFDocument(url: documentUrl),
            let page = document.page(at: pdfCanvas.pageNumber)
        else { throw PDFCanvasViewControllerError.pdfPageLoadFailed }
        return page
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Add delegate and returns id so it can be later removed
    func addDelegate(_ delegate: CanvasViewControllerDelegate) -> UUID {
        let id = UUID()
        delegates[id] = delegate
        return id
    }

    /// remove the delegate with given id
    func removeDelegate(id: UUID) {
        delegates.removeValue(forKey: id)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        setupPDFScrollView()

        setupInitialZoomAndZoomLimits()

        setupMapView()

        updatePDFMapSync()

//        setupDebugViews()
    }

    private func setupPDFScrollView() {
        pdfScrollView = PDFPageScrollView(frame: view.bounds, pdfPage: pdfPage)
        view.addSubview(pdfScrollView)
        pdfScrollView.scrollsToTop = false // we don't want scroll to top on top bar touch
        pdfScrollView.showsVerticalScrollIndicator = false
        pdfScrollView.showsHorizontalScrollIndicator = false
        pdfScrollView.bouncesZoom = false
    }

    /// Calculates initial mapbox zoom so the PDFPage fits the screen
    private func setupInitialZoomAndZoomLimits() {
        let pdfSizeInMeters = pdfPage.sizeInMeters(forScale: 1.0 / pdfCanvas.userDefinedScale)
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
        if pdfMapSync == .pdf {
            mapView = MapView(frame: view.bounds)
        } else {
            // set initial mapbox zoom level and position
            let cameraOptions = CameraOptions(center: model.projectSummary.center, zoom: initialZoom)
            mapView = MapView(frame: view.bounds, mapInitOptions: MapInitOptions(cameraOptions: cameraOptions))
        }
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
                Logger.mapbox.debug("annotations style loaded successfully")
            case let .failure(error):
                Logger.mapbox.error("annotations style load failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        do {
            try mapView.mapboxMap.setCameraBounds(with: CameraBoundsOptions(maxZoom: maxMapboxZoom))
        } catch {
            Logger.mapbox.error("set initial camera bounds failed: \(error.localizedDescription, privacy: .public)")
        }

        mapView.ornaments.options.attributionButton.visibility = .hidden
        mapView.ornaments.options.scaleBar.visibility = .hidden
        mapView.gestures.options.rotateEnabled = false
        mapView.gestures.options.pitchEnabled = false

        view.addSubview(mapView)
    }

    private func updatePDFMapSync() {
        if pdfMapSync == .mapAnnotations {
            setupSyncDriverAnnotationViews()
        } else {
            tearDownSyncDriverAnnotationViews()
        }
        if pdfMapSync == .pdf {
            pdfScrollView.pdfPageScrollViewDelegate = self
            if let canvasTapGestureRecognizer = canvasTapGestureRecognizer {
                mapView.removeGestureRecognizer(canvasTapGestureRecognizer)
            }
            canvasTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapCanvasView(_:)))
            pdfScrollView.addGestureRecognizer(canvasTapGestureRecognizer!)
            mapView.isUserInteractionEnabled = false
            mapView.gestures.delegate = nil
            mapboxCameraChangedObserver?.cancel()
            syncCameraStateWithPDFView()
        } else {
            pdfScrollView.pdfPageScrollViewDelegate = nil
            if let canvasTapGestureRecognizer = canvasTapGestureRecognizer {
                pdfScrollView.removeGestureRecognizer(canvasTapGestureRecognizer)
            }
            canvasTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapCanvasView(_:)))
            mapView.addGestureRecognizer(canvasTapGestureRecognizer!)
            mapView.isUserInteractionEnabled = true
            mapView.gestures.delegate = self
            mapboxCameraChangedObserver = mapView.mapboxMap.onEvery(event: .cameraChanged, handler: { [weak self] _ in
                guard let self = self else { return }
                self.syncPDFViewWithCameraState()
                if let currentCameraChangeReason = self.currentCameraChangeReason {
                    self.delegates.values.forEach { $0.canvasCameraChanged(reason: currentCameraChangeReason) }
                }
            })
            syncPDFViewWithCameraState()
        }
    }

    /// Add special mapbox annotation views that are transparent and act as a map -> pdf sync driver.
    private func setupSyncDriverAnnotationViews() {
        do {
            let pdfFrame = mapView.convert(pdfScrollView.pdfView.frame, from: pdfScrollView)
            let topLeft = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 100_001, height: 100_001)))
            topLeft.backgroundColor = .clear
            try mapView.viewAnnotations.add(topLeft, options: ViewAnnotationOptions(
                geometry: Turf.Point(mapView.mapboxMap.coordinate(for: pdfFrame.origin)),
                allowOverlap: true
            ))
            let bottomRight = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 100_001, height: 100_001)))
            bottomRight.backgroundColor = .clear
            try mapView.viewAnnotations.add(bottomRight, options: ViewAnnotationOptions(
                geometry: Turf.Point(mapView.mapboxMap.coordinate(for: CGPoint(x: pdfFrame.maxX, y: pdfFrame.maxY))),
                allowOverlap: true
            ))
            topLeftSyncAnnotationView = topLeft
            bottomRightSyncAnnotationView = bottomRight

            bottomRightSyncAnnotationViewObservation = bottomRight.observe(\.frame) { [weak self] _, _ in
                self?.syncPDFViewWithAnnotationViews()
            }
        } catch {
            Logger.mapbox.error("error adding mapbox sync driver view: \(error)")
        }
    }

    /// Remove the mapbox annotation views for driving mapbox -> pdf sync and stop observing
    private func tearDownSyncDriverAnnotationViews() {
        bottomRightSyncAnnotationViewObservation?.invalidate()

        if let topLeft = topLeftSyncAnnotationView {
            mapView.viewAnnotations.remove(topLeft)
            topLeftSyncAnnotationView = nil
        }
        if let bottomRight = bottomRightSyncAnnotationView {
            mapView.viewAnnotations.remove(bottomRight)
            bottomRightSyncAnnotationView = nil
        }
    }

    override func viewWillLayoutSubviews() {
        mapView.frame = view.bounds
    }

//    private func setupDebugViews() {
//        let resetButton = UIButton()
//        resetButton.setTitle("reset", for: .normal)
//        resetButton.addTarget(self, action: #selector(resetAction), for: .touchUpInside)
//        resetButton.sizeToFit()
//        resetButton.backgroundColor = .black.withAlphaComponent(0.5)
//        view.addSubview(resetButton)
//        resetButton.frame.origin = CGPoint(x: 10, y: 40)
//    }
//
//    @objc func resetAction() {
//        animatePanAndZoom(contentOffset: .zero, zoomScale: 1)
//    }

    /// Animate to given cameraCenter and mapboxZoom.
    func animatePanAndZoom(cameraCenter: CLLocationCoordinate2D, mapboxZoom: Double) {
        if pdfMapSync == .pdf {
            let endContentOffset = PDFCanvasViewController.mapboxCenterToScrollViewContentOffset(
                cameraCenter: cameraCenter,
                scrollView: pdfScrollView,
                initialCenter: model.projectSummary.center,
                initialMetersPerPoint: initialMetersPerPoint
            )
            let endZoomScale = initialMetersPerPoint / zoomConverter.getMetersPerPoint(forZoom: mapboxZoom)
            animatePanAndZoom(contentOffset: endContentOffset, zoomScale: endZoomScale)
        } else {
            // HACK: dispatch async on main queue is a hack, otherwise the mapbox was not reacting
            // when invoking this method on callback from gesture manager delegate
            DispatchQueue.main.async {
                self.programmaticAnimationInProgress = true
                let animator = self.mapView.camera.makeAnimator(duration: 0.2, curve: .easeOut) { transition in
                    transition.zoom.toValue = mapboxZoom
                    transition.center.toValue = cameraCenter
                }
                animator.addCompletion { [weak self] _ in
                    self?.programmaticAnimationInProgress = false
                }
                animator.startAnimation()
            }
        }
    }

    /// Animate to given pdf content offset  and zoom.
    /// To sync PDF and Mapbox we need to "manually" animate the scrollView contentOffset and zoom, so mapbox is synced along the way
    /// This is only needed when pdf drives interactions
    private func animatePanAndZoom(contentOffset endContentOffset: CGPoint, zoomScale endZoomScale: Double) {
        let duration = 0.2

        let startContentOffset = pdfScrollView.contentOffset
        let startZoomScale = pdfScrollView.zoomScale

        // any running animation?
        displayLink?.invalidate()
        programmaticAnimationInProgress = true
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
                self.programmaticAnimationInProgress = false
            }
        })
    }

    /// Set mapbox camera center and zoom based on current pdf view contentOffset and zoomScale
    private func syncCameraStateWithPDFView() {
        guard pdfMapSync == .pdf else { return }
        let cameraCenter = PDFCanvasViewController.scrollViewStateToMapboxCenter(
            scrollView: pdfScrollView,
            initialCenter: model.projectSummary.center,
            initialMetersPerPoint: initialMetersPerPoint
        )
        let metersPerPoint = initialMetersPerPoint / pdfScrollView.zoomScale
        let mapboxZoom = zoomConverter.getZoom(forMetersPerPoint: metersPerPoint)
        mapView.mapboxMap.setCamera(to: CameraOptions(center: cameraCenter, zoom: mapboxZoom))
    }

    /// Calculate and apply PDF zoom and offset based on current Mapbox camera state.
    private func syncPDFViewWithCameraState() {
        guard pdfMapSync == .mapCamera else { return }

        let cameraState = mapView.cameraState

        // offset is sync based on mapbox camera only in .mapboxCamera option, .mapboxCameraAndAnnotation syncs offset based on the annotation position
        let contentOffset = PDFCanvasViewController.mapboxCenterToScrollViewContentOffset(
            cameraCenter: cameraState.center,
            scrollView: pdfScrollView,
            initialCenter: model.projectSummary.center,
            initialMetersPerPoint: initialMetersPerPoint
        )
        pdfScrollView.contentOffset = contentOffset

        // translate current mapbox zoom to pdf UIView.zoomScale
        let currentMetersPerPoint = zoomConverter.getMetersPerPoint(forZoom: cameraState.zoom)
        pdfScrollView.zoomScale = initialMetersPerPoint / currentMetersPerPoint
    }

    /// Calculate and apply PDF offset and zoom based on the sync driving annotation views
    /// The calculations are based only on screen coordinates as the annotations were placed so their centers
    /// match the top-left and bottom-right corners of the PDF, so the PDF scale and offset can be inferred directly
    /// from current on screen positions of the annotation views, without doing any mapbox camera/zoom or geocoordinates calculations.
    private func syncPDFViewWithAnnotationViews() {
        guard let topLeftCenter = topLeftSyncAnnotationView?.center,
              let bottomRightCenter = bottomRightSyncAnnotationView?.center else { return }
        let syncViewsCenter = CGPoint(
            x: (topLeftCenter.x + bottomRightCenter.x) / 2,
            y: (topLeftCenter.y + bottomRightCenter.y) / 2
        )
        let syncViewsDistance = bottomRightCenter.x - topLeftCenter.x
        let scale: CGFloat
        // when the sync is run for the first time, read the current annotations distance
        // and this is the initial width (the reference for scaling)
        if let initialWidth = initialSyncViewsDistance {
            scale = syncViewsDistance / initialWidth
        } else {
            initialSyncViewsDistance = syncViewsDistance
            scale = pdfScrollView.zoomScale
        }
        pdfScrollView.zoomScale = scale

        let xOffset = -(syncViewsCenter.x - pdfScrollView.center.x * scale)
        let yOffset = -(syncViewsCenter.y - pdfScrollView.center.y * scale)
        pdfScrollView.contentOffset = CGPoint(x: xOffset, y: yOffset)
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

/// Delegate for Mapbox driving gestures
extension PDFCanvasViewController: GestureManagerDelegate {
    func gestureManager(_: MapboxMaps.GestureManager, didBegin gesture: MapboxMaps.GestureType) {
        guard gesture != .singleTap else {
            // taps are not handled as camera changes, but rather forwarded to delegates via canvasTapRecognized
            return
        }
        let canvasCameraChangeReason = programmaticAnimationInProgress
            ? .programmatic
            : CanvasCameraChangeReason(fromGesture: gesture)
        delegates.values.forEach { $0.canvasCameraChanged(reason: canvasCameraChangeReason) }
        currentCameraChangeReason = canvasCameraChangeReason
    }

    func gestureManager(_: MapboxMaps.GestureManager, didEnd gesture: MapboxMaps.GestureType, willAnimate: Bool) {
        guard gesture != .singleTap else {
            // taps are not handled as camera changes, but rather forwarded to delegates via canvasTapRecognized
            return
        }
        if !willAnimate {
            let canvasCameraChangeReason = programmaticAnimationInProgress
                ? .programmatic
                : CanvasCameraChangeReason(fromGesture: gesture, end: true)
            delegates.values.forEach { $0.canvasCameraChanged(reason: canvasCameraChangeReason) }
            currentCameraChangeReason = nil
        }
    }

    func gestureManager(_: MapboxMaps.GestureManager, didEndAnimatingFor gesture: MapboxMaps.GestureType) {
        let canvasCameraChangeReason = programmaticAnimationInProgress
            ? .programmatic
            : CanvasCameraChangeReason(fromGesture: gesture, end: true)
        delegates.values.forEach { $0.canvasCameraChanged(reason: canvasCameraChangeReason) }
        currentCameraChangeReason = nil
    }
}

/// Delegate for canvas taps
extension PDFCanvasViewController {
    /// Recognize taps in the pdf view or mapView, translate to mapbox view and forward to delegates using canvasTapRecognized.
    @objc func didTapCanvasView(_ sender: UITapGestureRecognizer) {
        let point = sender.location(in: sender.view)
        guard let pointInMapView = sender.view?.convert(point, to: mapView) else { return }
        delegates.values.forEach {
            $0.canvasTapRecognized(at: pointInMapView)
        }
    }
}

/// Delegate for PDF driving scroll view
extension PDFCanvasViewController: PDFPageScrollViewDelegate {
    func scrollViewDidScroll(_: PDFPageScrollView) {
        // controlled animation syncs the state itself
        if !programmaticAnimationInProgress {
            syncCameraStateWithPDFView()
        }
        delegates.values.forEach {
            $0.canvasCameraChanged(reason: programmaticAnimationInProgress ? .programmatic : .pan)
        }
    }

    func scrollViewDidZoom(_: PDFPageScrollView) {
        // controlled animation syncs the state itself
        if !programmaticAnimationInProgress {
            syncCameraStateWithPDFView()
        }
        delegates.values.forEach {
            $0.canvasCameraChanged(reason: programmaticAnimationInProgress ? .programmatic : .zoom)
        }
    }

    /// Notify about panEnd but only if not decelerating (if decelerating the panEnd will be notified on deceleration end)
    /// Do not notiy when programmaticAnimationInProgress - these are only interesting for user interactions
    func scrollViewDidEndDragging(_: PDFPageScrollView, willDecelerate decelerate: Bool) {
        if !decelerate, !programmaticAnimationInProgress {
            delegates.values.forEach {
                $0.canvasCameraChanged(reason: .panEnd)
            }
        }
    }

    /// Notify about panEnd when there was a deceleration
    /// Do not notiy when programmaticAnimationInProgress - these are only interesting for user interactions
    func scrollViewDidEndDecelerating(_: PDFPageScrollView) {
        if !programmaticAnimationInProgress {
            delegates.values.forEach {
                $0.canvasCameraChanged(reason: .panEnd)
            }
        }
    }

    /// Notify about zoomEnd when there was a deceleration
    /// Do not notiy when programmaticAnimationInProgress - these are only interesting for user interactions
    func scrollViewDidEndZooming(_: PDFPageScrollView, with _: UIView?, atScale _: CGFloat) {
        if !programmaticAnimationInProgress {
            delegates.values.forEach {
                $0.canvasCameraChanged(reason: .zoomEnd)
            }
        }
    }
}
