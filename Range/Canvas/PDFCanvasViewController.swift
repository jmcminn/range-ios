import CoreLocation
@_spi(Restricted) @_spi(Experimental) import MapboxMaps
import OSLog
import PDFKit
import RealmSwift
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

/**
 Displays background PDF with Mapbox map view on top.
 The mapbox map is receiving the user interactions and controls the PDF zoom/offset
 */
class PDFCanvasViewController: UIViewController {
    // Should the canvas display PDF or mapbox map
    enum CanvasType {
        case pdf
        case mapbox
    }

    private var canvasType: CanvasType

    let maxMapboxZoom = 25.5

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
    private var pdfCanvas: PDFCanvas
    private var pdfPage: PDFPage

    let zoomConverter: MapboxZoomConverter

    var mapView: MapView!
    var pdfScrollView: PDFPageScrollView?

    /// Initial mapbox zoom matching the pdf page fitting the view
    private var initialZoom: Double = 0.0

    /// when animating the pdf and mapview together, we need to disable the sync of zoom/center between them
    private var programmaticAnimationInProgress = false

    /// dictionary of delegates stored per id
    private var delegates: [UUID: CanvasViewControllerDelegate] = [:]

    /// To observed changes in model.currentCanvas
    private var canvasObservation: NSKeyValueObservation?
    /// Observe canvas collection for pdf storage version change to reload the pdf
    private var canvasCollectionNotificationToken: NotificationToken?

    /// A default empty style for annotations with path to local glyphs
    var annotationsStyle: String {
        "{}"
//        guard let fontsPath = Bundle.main.path(forResource: "fonts", ofType: nil) else {
//            Logger.assets.fault("Couldn't find fonts, Mapbox will be broken")
//            return "{}"
//        }
//        return
//            """
//            {
//            "glyphs": "file://\(fontsPath)/{fontstack}/{range}.pbf"
//            }
//            """
    }

    init(model: ProjectModel) async throws {
        canvasType = .pdf
        self.model = model
        pdfCanvas = model.currentCanvas
        pdfPage = try await CanvasFileLoader().loadPDFPage(forCanvas: pdfCanvas, projectId: model.projectId)
        zoomConverter = MapboxZoomConverter(latitude: model.projectSummary.center.latitude)
        super.init(nibName: nil, bundle: nil)

        observeCanvasCollection()
        canvasObservation = model.observe(\.currentCanvas) { [weak self] _, _ in
            guard let self = self else { return }
            Task { @MainActor in
                // update the pdfCanvas
                self.pdfCanvas = self.model.currentCanvas
                self.observeCanvasCollection()
                if self.canvasType == .pdf {
                    await self.reloadPDFScrollView()
                }
            }
        }
    }

    /// toggle canvas type to switch between mapbox / pdf background - just for prototyping. The production solution will have a
    /// separate canvas for mapbox
    func toggleCanvasType() {
        if canvasType == .mapbox {
            // Switch to pdf
            canvasType = .pdf
            setupPDFScrollView()
            mapView.removeFromSuperview()
            mapView = nil
            setupMapView()
            setupSyncAnnotationViews()
        } else {
            // Switch to mapbox
            canvasType = .mapbox
            tearDownSyncAnnotationViews()
            pdfScrollView?.removeFromSuperview()
            pdfScrollView = nil
            mapView.removeFromSuperview()
            mapView = nil
            setupMapView()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        canvasObservation?.invalidate()
        canvasCollectionNotificationToken?.invalidate()
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

    /// update the canvas collection observation
    private func observeCanvasCollection() {
        canvasCollectionNotificationToken?.invalidate()
        if canvasType == .pdf {
            if let collection = pdfCanvas.collection.first {
                canvasCollectionNotificationToken = collection.observe { [weak self] _ in
                    Task { @MainActor in
                        // update the pdfCanvas
                        await self?.reloadPDFScrollView()
                    }
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        // 1. setup scroll view with given pdf page
        if canvasType == .pdf {
            setupPDFScrollView()
        }

        // 2. calculate the initialMetersPerPoint given the pdf page, view size and user defined scale
        setupInitialZoom()

        // 3. initiate mapview with initial zoom
        setupMapView()

        // 4. setup annotation views
        if canvasType == .pdf {
            setupSyncAnnotationViews()
        }

//        setupDebugViews()
    }

    /// This is called when canvas changes after loading the initial canvas.
    /// We keep the zoom/offset, so there's no recalculation of initial zoom.
    @MainActor
    private func reloadPDFScrollView() async {
        // first hide the previous pdf view
        pdfScrollView?.removeFromSuperview()
        do {
            // load the page
            pdfPage = try await CanvasFileLoader().loadPDFPage(forCanvas: pdfCanvas, projectId: model.projectId)
            // build new view
            setupPDFScrollView()
            // sync with current zoom/offset from mapbox
            syncPDFViewWithAnnotationViews()
        } catch {
            Logger.model.error("load canvas error: \(error.localizedDescription, privacy: .public)")
            ToastWindow.shared.showError(text: "Failed to load the canvas")
        }
    }

    private func setupPDFScrollView() {
        let pdfScrollView = PDFPageScrollView(frame: view.bounds, pdfPage: pdfPage)
        view.insertSubview(pdfScrollView, at: 0)
        pdfScrollView.scrollsToTop = false // we don't want scroll to top on top bar touch
        pdfScrollView.showsVerticalScrollIndicator = false
        pdfScrollView.showsHorizontalScrollIndicator = false
        pdfScrollView.bouncesZoom = false
        // just a small number and a big number, the zoom is controlled by the mapbox anyway.
        pdfScrollView.minimumZoomScale = 0.001
        pdfScrollView.maximumZoomScale = 100_000

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
        self.pdfScrollView = pdfScrollView
    }

    /// Calculates initial zoom for mapbox, so it matches the zoom scale of PDFPage when it fits the view
    private func setupInitialZoom() {
        let pdfSizeInMeters = pdfPage.sizeInMeters(forScale: 1.0 / pdfCanvas.userDefinedScale)
        let pdfWidthMetersPerPoint = pdfSizeInMeters.width / view.bounds.width
        let pdfHeightMetersPerPoint = pdfSizeInMeters.height / view.bounds.height
        let initialMetersPerPoint = max(pdfWidthMetersPerPoint, pdfHeightMetersPerPoint)
        initialZoom = zoomConverter.getZoom(forMetersPerPoint: initialMetersPerPoint)
    }

    private func setupMapView() {
        // set initial mapbox zoom level and position
        let cameraOptions = CameraOptions(center: model.projectSummary.center, zoom: initialZoom)
        let mapInitOptions: MapInitOptions
        if canvasType == .pdf {
            mapInitOptions = MapInitOptions(cameraOptions: cameraOptions)
        } else {
            // We only need the access token if using mapbox resources, so it's not needed when displaying
            // the PDF background
            ResourceOptionsManager.default.resourceOptions.accessToken =
                "pk.eyJ1IjoicmFuZ2UtbWFwYm94IiwiYSI6ImNsZXBkbmZycTA3aGYzcm1qZmtsZmFxaGoifQ.Tf0zWjw79qKgcFLh7XCTRQ"
            mapInitOptions = MapInitOptions(cameraOptions: cameraOptions, styleURI: StyleURI.satelliteStreets)
        }
        mapView = MapView(frame: view.bounds, mapInitOptions: mapInitOptions)

        if canvasType == .pdf {
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
                    Logger.mapbox
                        .error("annotations style load failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        do {
            try mapView.mapboxMap.setCameraBounds(with: CameraBoundsOptions(maxZoom: maxMapboxZoom))
        } catch {
            Logger.mapbox.error("set initial camera bounds failed: \(error.localizedDescription, privacy: .public)")
        }

        mapView.ornaments.options.attributionButton.visibility = .hidden
        mapView.ornaments.options.scaleBar.visibility = .hidden
        if canvasType == .pdf {
            // rotations and pitch change is not supported for PDF
            mapView.gestures.options.rotateEnabled = false
            mapView.gestures.options.pitchEnabled = false
        }
        mapView.isUserInteractionEnabled = true

        view.addSubview(mapView)

        canvasTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapCanvasView(_:)))
        mapView.addGestureRecognizer(canvasTapGestureRecognizer!)
        mapView.gestures.delegate = self
        mapboxCameraChangedObserver = mapView.mapboxMap.onEvery(event: .cameraChanged, handler: { [weak self] _ in
            guard let self = self, let currentCameraChangeReason = self.currentCameraChangeReason else { return }
            self.delegates.values.forEach { $0.canvasCameraChanged(reason: currentCameraChangeReason) }
        })
    }

    /// Add special mapbox annotation views that are transparent and act as a map -> pdf sync driver.
    private func setupSyncAnnotationViews() {
        guard let pdfScrollView = pdfScrollView else {
            fatalError("setupSyncAnnotationViews called when pdfScrollView is nil")
        }
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
            Logger.mapbox.error("error adding mapbox sync view: \(error)")
        }
    }

    /// Remove the mapbox annotation views for driving mapbox -> pdf sync and stop observing
    private func tearDownSyncAnnotationViews() {
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
        // HACK: dispatch async on main queue is a hack, otherwise the mapbox was not reacting
        // when invoking this method on callback from gesture manager delegate
        DispatchQueue.main.async {
            self.programmaticAnimationInProgress = true
            let animator = self.mapView.camera.makeAnimator(duration: 0.2, curve: .easeOut) { transition in
                transition.zoom.toValue = mapboxZoom
                transition.center.toValue = cameraCenter
            }
            animator.addCompletion { [weak self] _ in
                guard let self = self else { return }
                self.delegates.values.forEach { $0.canvasCameraChanged(reason: .programmatic) }
                self.programmaticAnimationInProgress = false
            }
            animator.startAnimation()
        }
    }

    /// Calculate and apply PDF offset and zoom based on the sync driving annotation views
    /// The calculations are based only on screen coordinates as the annotations were placed so their centers
    /// match the top-left and bottom-right corners of the PDF, so the PDF scale and offset can be inferred directly
    /// from current on screen positions of the annotation views, without doing any mapbox camera/zoom or geocoordinates calculations.
    private func syncPDFViewWithAnnotationViews() {
        guard let pdfScrollView = pdfScrollView else {
            fatalError("syncPDFViewWithAnnotationViews called when pdfScrollView is nil")
        }
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
