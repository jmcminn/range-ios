import CoreLocation
@_spi(Restricted) @_spi(Experimental) import MapboxMaps
import MetalKit
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
    /// User has long pressed at given point
    func canvasLongPressRecognized(at: CGPoint)
}

/// Stores the state needed to restore map for given canvas source. Used when switching between canvas (sources)
struct CanvasSourceMapState {
    var cameraState: CameraState

    // Pdf canvas source:
    // we only calculate the sync annotation views coordinates once when the canvas source is loaded
    // as this is the time where the map has the initial center/zoom/rotation for a canvas source,
    // later when user switches canvases/canvas sources we restore to the last camera state (while the
    // project is open)
    var topLeftAnnotationViewCoordinate: CLLocationCoordinate2D?
    var bottomRightAnnotationViewCoordinate: CLLocationCoordinate2D?
}

/// Displays a mapbox map view for canvas.
///
/// - For PDF canvas sources it shows the PDF view behind the map view (with an empty style so there's no map visible).  In this case
/// the mapbox map is receiving the user interactions and controls the PDF zoom/offset.
///
/// - For mapbox and drone deploy sources it just displays the style defined in the source.
class CanvasViewController: UIViewController {
    static let maxMapboxZoom = 25.5

    let zoomConverter: MapboxZoomConverter

    /// observers for pdf/mapbox views. They're being activated/deactivated when switching who drives the interactions
    private var canvasTapGestureRecognizer: UITapGestureRecognizer?
    private var cancelables = Set<AnyCancelable>()
    /// Size of an imaginary square that helps synchronize pdf zoom/offset with mapbox map (and actually with 2 mapbox annotations
    /// placed at the corners of this square). See `setupSyncAnnotationViews` for more details
    private let syncSquareSize: Double = 200
    /// For setting up the pdf sync we need mapbox started with some reference zoom (defined by this property)
    private let initialMapboxZoom: Double = 19.0
    // 2 annotation views used for .mapAnnotations pdf<->map sync
    private var topLeftSyncViewAnnotation: ViewAnnotation?
    private var bottomRightSyncViewAnnotation: ViewAnnotation?
    // observe the bottom right sync view
    private var bottomRightSyncAnnotationViewObservation: NSKeyValueObservation?

    /// For case when mapbox drives the interactions we need to store the current gesture (for example 'pan') to continuously
    /// report panning when the camera changes. (the mapbox gestures delegate only reports start/end of gesture)
    private var currentCameraChangeReason: CanvasCameraChangeReason?

    let model: ProjectModel
    let canvasFileLoader: CanvasFileLoader
    private(set) var canvas: Canvas
    // only when displaying pdf source
    private(set) var pdfPage: PDFPage?

    /// Mapbox for rendering the background mapview for .mapbox and .dronedeploy sources and for rendering the pins for all sources
    /// Achtung: reloading mapView instance when switching sources is not supported now. So when switching sources the initial
    /// mapView instance needs to be used instead of creating a new one, because pins are already added to it, and are only reloaded
    /// if the canvas changes. If we wanted to reload map view on canvas/canvasSource change we would need to "notify" pins to reload
    /// **after** the new mapView instance is created.
    private(set) var mapView: MapView!
    var pdfScrollView: PDFPageScrollView?

    /// Remember the state when switching canvas sources. A dictionary of CanvasSource.id => CanvasSourceMapState
    private var canvasSourceMapStateCache = [String: CanvasSourceMapState]()

    /// when animating the pdf and mapview together, we need to disable the sync of zoom/center between them
    private var programmaticAnimationInProgress = false

    /// dictionary of delegates stored per id
    private var delegates: [UUID: CanvasViewControllerDelegate] = [:]

    /// To observe changes in model.currentCanvas
    private var currentCanvasObservation: NSKeyValueObservation?
    /// To observe changes in model.currentCanvas.currentCanvasSource
    private var currentCanvasSourceObservation: NSKeyValueObservation?
    /// Observe canvas source for pdf storage version change to reload the pdf
    private var canvasSourceNotificationToken: NotificationToken?

    /// Current location provider
    private let locationProvider: LocationProvider & HeadingProvider

    init(
        model: ProjectModel,
        canvasFileLoader: CanvasFileLoader,
        locationProvider: LocationProvider & HeadingProvider
    ) async throws {
        self.model = model
        self.canvasFileLoader = canvasFileLoader
        self.locationProvider = locationProvider
        canvas = model.currentCanvas
        zoomConverter = MapboxZoomConverter(latitude: model.projectSummary.center.latitude)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        currentCanvasObservation?.invalidate()
        currentCanvasSourceObservation?.invalidate()
        canvasSourceNotificationToken?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        let gridView = GridView(frame: view.bounds)
        view.insertSubview(gridView, at: 0)

        // initiate mapview
        setupMapView()
        // setup once, the annotations should be added as first to map view, so all the pins
        // are above
        setupSyncAnnotationViews()

        currentCanvasObservation = model.observe(\.currentCanvas) { [weak self] _, _ in
            guard let self else { return }
            Task { @MainActor in
                await self.showCanvas(previousCanvas: self.canvas)
            }
        }

        Task { @MainActor in
            await self.showCanvas(previousCanvas: nil)
        }

//        setupDebugViews()
    }

    /// Show the current model canvas
    private func showCanvas(previousCanvas: Canvas?) async {
        guard model.currentCanvas.id != previousCanvas?.id else { return }
        canvas = model.currentCanvas
        setFollowMeMode(enabled: false)
        observeCurrentCanvasSource()
        observeCanvasSourceChanges()
        await showCanvasSource(previousCanvasSource: previousCanvas?.currentCanvasSource)
    }

    /// Show the current canvas source
    private func showCanvasSource(previousCanvasSource: CanvasSource?) async {
        if let previousCanvasSource {
            // store the camera state so it can be reused when switching back to same canvas source
            var state = CanvasSourceMapState(cameraState: mapView.mapboxMap.cameraState)
            if previousCanvasSource.type == .pdf,
               case let .point(topLeftPoint) = topLeftSyncViewAnnotation?.annotatedFeature.geometry,
               case let .point(bottomRightPoint) = bottomRightSyncViewAnnotation?.annotatedFeature.geometry
            {
                state.topLeftAnnotationViewCoordinate = topLeftPoint.coordinates
                state.bottomRightAnnotationViewCoordinate = bottomRightPoint.coordinates
            }
            canvasSourceMapStateCache[previousCanvasSource.id] = state
        }
        updateMapViewForCanvasSource()

        if canvas.currentCanvasSource.type == .pdf {
            await loadPDFScrollView(forceReload: false)
        } else {
            updateCameraForCanvasSource(useStateCache: true)
            pdfScrollView?.removeFromSuperview()
            pdfScrollView = nil
        }
    }
    
    // reset rotation to the default value
    func resetRotationForPdf() {
        var cameraState = mapView.mapboxMap.cameraState
        cameraState.bearing = canvas.currentCanvasSource.rotation
        mapView.mapboxMap.setCamera(to: CameraOptions(cameraState: cameraState))
    }
    
    // disable rotation if the current canvas source is pdf
    func disableRotationForPdf() {
        mapView.gestures.options.rotateEnabled = canvas.currentCanvasSource.type != .pdf
    }
    
    // enable rotation for supported canvases
    func enableRotation() {
        mapView.gestures.options.rotateEnabled = canvas.currentCanvasSource.isGeolocated
    }

    /// Observe when canvas source is switched to different canvas source
    private func observeCurrentCanvasSource() {
        currentCanvasSourceObservation?.invalidate()
        currentCanvasSourceObservation = model.currentCanvas
            .observe(\.currentCanvasSource, options: [.old]) { [weak self] _, change in
                guard let self = self else { return }
                self.observeCanvasSourceChanges()
                setFollowMeMode(enabled: false)

                guard let previousCanvasSource = change.oldValue ?? nil else {
                    return
                }
                Task { @MainActor in
                    await self.showCanvasSource(previousCanvasSource: previousCanvasSource)
                }
            }
    }

    /// Observe when canvas source is updated
    private func observeCanvasSourceChanges() {
        canvasSourceNotificationToken?.invalidate()
        if canvas.currentCanvasSource.type == .pdf {
            // observe pdf source for storage version (or any) update to reload the pdf
            canvasSourceNotificationToken = canvas.currentCanvasSource.observe { [weak self] _ in
                Task { @MainActor in
                    // update the pdfCanvas
                    await self?.loadPDFScrollView(forceReload: true)
                }
            }
        }
    }

    /// Convert given frame from this view coordinates into PDF page coordinates for currently displayed PDF page
    /// (so based on the current display of pdf - zoom, pan, get which part of the pdf page is inside given viewFrame)
    /// The result is in PDFPage .mediaBox coordinates (not view coordinates)
    func getPDFPageFrameForViewFrame(_ viewFrame: CGRect) -> CGRect {
        guard let page = pdfPage, let pdfView = pdfScrollView?.pdfView else {
            fatalError("pdf page or view missing foc pdf canvas source")
        }

        // this gives the part of the pdf view visible inside the viewFrame
        // it's all in pdfView units (not in the pdf page coordinates)
        let viewFrameInPdfViewCoordinates = view.convert(
            viewFrame,
            to: pdfView
        )
        // the size reported by the PDF page (unrelated to view rendering)
        let pageBounds = page._sizeAdjustedForRotation(for: .mediaBox)
        // pdf page size to the rendered view ratio
        let pageBoundsToViewFrameRatio = pageBounds.width / pdfView.frame.width
        // viewFrame in the coordinates of the page bounds (in PDF units, unrelated to view rendering)
        return CGRect(
            x: viewFrameInPdfViewCoordinates.origin.x * pageBoundsToViewFrameRatio,
            y: viewFrameInPdfViewCoordinates.origin.y * pageBoundsToViewFrameRatio,
            width: viewFrameInPdfViewCoordinates.width * pageBoundsToViewFrameRatio,
            height: viewFrameInPdfViewCoordinates.height * pageBoundsToViewFrameRatio
        )
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

    /// This is called when canvas PDF changes after loading the initial canvas.
    /// We keep the zoom/offset, so there's no recalculation of initial zoom.
    /// - Parameters:
    ///   - forceReload - ignored any cached canvas source state (like the last camera settings) and show with initial center, etc.
    @MainActor
    private func loadPDFScrollView(forceReload: Bool) async {
        guard !canvas.isInvalidated, !canvas.currentCanvasSource.isInvalidated else { return }
        // first hide the previous pdf view
        pdfScrollView?.removeFromSuperview()
        pdfScrollView = nil

        guard canvas.currentCanvasSource.type == .pdf else { return }

        do {
            // load the page
            try await reloadPdfPage()
        } catch {
            let sourceId = canvas.currentCanvasSource.id
            Logger.model.error(
                "Failed to load pdf for canvas source \(sourceId, privacy: .public), \(error.localizedDescription, privacy: .public)"
            )
            ToastWindow.shared.showError(text: "Canvas failed to load")
        }
        // build new view
        DispatchQueue.main.async {
            self.setupPDFScrollView()
            // update the map view camera when switching canvases
            self.updateCameraForCanvasSource(useStateCache: !forceReload)
            // setup annotation views
            self.updateSyncAnnotationViewsForCanvasSource(useStateCache: !forceReload)

            self.syncPDFViewWithAnnotationViews()
        }
    }

    @MainActor
    private func reloadPdfPage() async throws {
        pdfPage = try await canvasFileLoader.loadPDFPage(
            forSource: canvas.currentCanvasSource,
            projectId: model.projectId
        )
    }

    /// Setup the PDF scroll view appropriately for current canvas source. (if not needed then removes the current one)
    private func setupPDFScrollView() {
        pdfScrollView?.removeFromSuperview()
        pdfScrollView = nil

        guard canvas.currentCanvasSource.type == .pdf else { return }

        guard let pdfPage else {
            fatalError("setupPDFScrollView called when pdfPage is nil")
        }

        let pdfScrollView = PDFPageScrollView(frame: view.bounds, pdfPage: pdfPage)
        view.insertSubview(pdfScrollView, at: 1)
        pdfScrollView.scrollsToTop = false // we don't want scroll to top on top bar touch
        pdfScrollView.showsVerticalScrollIndicator = false
        pdfScrollView.showsHorizontalScrollIndicator = false
        pdfScrollView.bouncesZoom = false
        // just a small number and a big number, the zoom is controlled by the mapbox anyway.
        pdfScrollView.minimumZoomScale = 0.001
        pdfScrollView.maximumZoomScale = 100_000
        // When pdf is rotated it's bounds are not matching the superview bounds so we may
        // need to render outside of bounds
        pdfScrollView.clipsToBounds = false

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

    /// Based on the pdf properties and current pdf view size calculate what's the ratio of real world meters per screen point for pdf
    private func getInitialMetersPerPointForPdf() -> Double {
        guard canvas.currentCanvasSource.type == .pdf,
              let userDefinedScale = canvas.currentCanvasSource.userDefinedScale
        else {
            fatalError("getInitialMetersPerPointForPdf called when canvas source is not pdf")
        }
        guard let pdfPage else {
            fatalError("getInitialMetersPerPointForPdf called when pdfPage is nil")
        }
        let pdfSizeInMeters = pdfPage.sizeInMeters(forScale: 1.0 / userDefinedScale)
        let pdfWidthMetersPerPoint = pdfSizeInMeters.width / view.bounds.width
        let pdfHeightMetersPerPoint = pdfSizeInMeters.height / view.bounds.height
        let initialMetersPerPoint = max(pdfWidthMetersPerPoint, pdfHeightMetersPerPoint)
        return initialMetersPerPoint
    }

    /// Returns the zoom based on the current canvas/canvasSource
    /// - for pdf it matches the zoom scale of PDFPage when it fits the view
    /// - otherwise it uses the zoom defined in the source
    private func getZoomForCurrentCanvasSource() -> Double {
        switch canvas.currentCanvasSource.type {
        case .pdf:
            let initialMetersPerPoint = getInitialMetersPerPointForPdf()
            /// Initial mapbox zoom matching the pdf page fitting the view
            return zoomConverter.getZoom(forMetersPerPoint: initialMetersPerPoint)
        default:
            return canvas.currentCanvasSource.zoom!
        }
    }

    // initial setup of map view
    private func setupMapView() {
        guard mapView == nil else {
            fatalError("setupMapView called when mapView is not nil")
        }
        // set initial mapbox zoom level and position, this will be changed for given canvas source
        let cameraOptions = CameraOptions(
            center: model.projectSummary.center,
            zoom: initialMapboxZoom
        )
        mapView = MapView(
            frame: view.bounds,
            mapInitOptions: MapInitOptions(cameraOptions: cameraOptions)
        )

        do {
            try mapView.mapboxMap
                .setCameraBounds(with: CameraBoundsOptions(maxZoom: CanvasViewController.maxMapboxZoom))
        } catch {
            Logger.mapbox.error("set initial camera bounds failed: \(error.localizedDescription, privacy: .public)")
        }

        mapView.ornaments.options.attributionButton.visibility = .hidden
        mapView.ornaments.options.scaleBar.visibility = .hidden
        // compass y position is hardcoded to be below top bar and canvas name banner
        mapView.ornaments.options.compass.margins = CGPoint(x: 8, y: 86)

        mapView.isUserInteractionEnabled = true
        view.addSubview(mapView)

        canvasTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapCanvasView))
        mapView.addGestureRecognizer(canvasTapGestureRecognizer!)
        mapView.addGestureRecognizer(
            UILongPressGestureRecognizer(target: self, action: #selector(didLongPressCanvasView))
        )
        mapView.gestures.delegate = self
        mapView.mapboxMap.onCameraChanged.observe { [weak self] _ in
            guard let self = self, let currentCameraChangeReason = self.currentCameraChangeReason else { return }
            self.delegates.values.forEach { $0.canvasCameraChanged(reason: currentCameraChangeReason) }
        }.store(in: &cancelables)
    }

    /// Reload the style and do other changes when canvas source changes
    private func updateMapViewForCanvasSource() {
        if canvas.currentCanvasSource.type == .pdf {
            // hack to make the Metal subview of the mapView transparent
            // (Mapbox iOS SDK doesn't expose any official way for making the map view transparent,
            // by default it's black even if there's no layers). The trick is to make
            // the MTKView used by Mapbox non opaque
            mapView.subviews.forEach { subview in
                if subview is MTKView {
                    subview.isOpaque = false
                }
            }
            // pitch change is not supported for PDF
            mapView.gestures.options.pitchEnabled = false
            // hide the compass for pdf. We could in theory show it if it's geolocated, but there's
            // no way to disable it, and we don't want user to rotate the map by tapping it.
            mapView.ornaments.options.compass.visibility = .hidden
            // When debugging the map view with PDF:
//            mapView.layer.opacity = 0.5
        } else {
            mapView.subviews.forEach { subview in
                if subview is MTKView {
                    subview.isOpaque = true
                }
            }
            mapView.gestures.options.pitchEnabled = true
            mapView.ornaments.options.compass.visibility = .adaptive
//            mapView.layer.opacity = 1
        }
        enableRotation()

        mapView.mapboxMap._loadMapboxStyle(forCanvasSource: canvas.currentCanvasSource)

        if canvas.currentCanvasSource.isGeolocated {
            // location support enabled
            mapView.location.override(provider: locationProvider)
            let blueDotPrototype = Puck2DConfiguration(
                topImage: UIImage()
                    .addCircleBackground(
                        bgSize: CGSize(width: 16, height: 16), bgColor: .BlueDotBlue, strokeColor: .BlueDotBlue
                    ),
                shadowImage: UIImage(named: "bluedot_background")
            )
            mapView.location.options.puckType = .puck2D(blueDotPrototype)
            mapView.location.options.puckBearingEnabled = true
        } else {
            // no location support
            mapView.location.options.puckType = nil
        }
    }

    /// resets the camera for given canvas source
    /// - Parameters:
    ///   - useStateCache - if true it tries to reset camera to the last state (if this canvas source was already shown in this project session)
    private func updateCameraForCanvasSource(useStateCache: Bool) {
        let state: CanvasSourceMapState? = useStateCache
            ? canvasSourceMapStateCache[canvas.currentCanvasSource.id]
            : nil
        let cameraState = state?.cameraState
            ?? CameraState(
                center: canvas.currentCanvasSource.center,
                padding: .zero,
                zoom: getZoomForCurrentCanvasSource(),
                bearing: canvas.currentCanvasSource.rotation,
                pitch: 0
            )
        mapView.mapboxMap.setCamera(to: CameraOptions(cameraState: cameraState))
    }

    /// Add special mapbox annotation views that are transparent and act as a map -> pdf sync driver. Does nothing when canvas source is not pdf.
    /// These are just to special annotations placed in the top left and bottom right corners of a square that has a side length = `syncSquareSize` points (in screen coordiantes)
    /// and is centered at the mapView center
    /// This function just adds the views at the project center, the actual positions are calculated in `updateSyncAnnotationViewsForCanvasSource`
    /// for each PDF canvas source when it's shown
    private func setupSyncAnnotationViews() {
        // this is the size in screen coordiantes. It needs to be very big as mapbox only tracks
        // annotations that are currently on screen. Such big size guarantess that no matter
        // what zoom and center this annotation view is partially on screen (but still not visible
        // as it's an empty view with alpha = 0)
        let annotationViewSize = CGSize(width: 100_001, height: 100_001)

        let topLeft = UIView(frame: CGRect(origin: .zero, size: annotationViewSize))
        topLeft.backgroundColor = .clear
        let topLeftViewAnnotation = ViewAnnotation(coordinate: model.projectSummary.center, view: topLeft)
        topLeftViewAnnotation.allowOverlap = true
        topLeftViewAnnotation.allowOverlapWithPuck = true
        mapView.viewAnnotations.add(topLeftViewAnnotation)
        topLeftSyncViewAnnotation = topLeftViewAnnotation

        let bottomRight = UIView(frame: CGRect(origin: .zero, size: annotationViewSize))
        bottomRight.backgroundColor = .clear
        let bottomRightViewAnnotation = ViewAnnotation(coordinate: model.projectSummary.center, view: bottomRight)
        bottomRightViewAnnotation.allowOverlap = true
        bottomRightViewAnnotation.allowOverlapWithPuck = true
        mapView.viewAnnotations.add(bottomRightViewAnnotation)

        bottomRightSyncViewAnnotation = bottomRightViewAnnotation

        // show topLeft/bottomRight dots to help debug
//        let dotFrame = CGRect(origin: CGPoint(x: 50000 - 3, y: 50000 - 3), size: CGSize(width: 7, height: 7))
//        let topLeftDot = UIView(frame: dotFrame)
//        topLeftDot.layer.cornerRadius = 3.5
//        topLeftDot.backgroundColor = .Red_03
//        topLeft.addSubview(topLeftDot)
//        let bottomRightDot = UIView(frame: dotFrame)
//        bottomRightDot.layer.cornerRadius = 3.5
//        bottomRightDot.backgroundColor = .Green_03
//        bottomRight.addSubview(bottomRightDot)

        bottomRightSyncAnnotationViewObservation = bottomRight.observe(\.frame) { [weak self] _, _ in
            self?.syncPDFViewWithAnnotationViews()
        }
    }

    private func updateSyncAnnotationViewsForCanvasSource(useStateCache: Bool) {
        guard let topLeftSyncViewAnnotation, let bottomRightSyncViewAnnotation else { return }

        let topLeftCoordinate: CLLocationCoordinate2D
        let bottomRightCoordinate: CLLocationCoordinate2D

        let state: CanvasSourceMapState? = useStateCache
            ? canvasSourceMapStateCache[canvas.currentCanvasSource.id]
            : nil
        if let topLeftAnnotationViewCoordinate = state?.topLeftAnnotationViewCoordinate,
           let bottomRightAnnotationViewCoordinate = state?.bottomRightAnnotationViewCoordinate
        {
            topLeftCoordinate = topLeftAnnotationViewCoordinate
            bottomRightCoordinate = bottomRightAnnotationViewCoordinate
        } else {
            let centerCoordinate = canvas.currentCanvasSource.center // geo
            let centerPoint = mapView.mapboxMap.point(for: centerCoordinate) // screen

            // The sync points need no canvasSource rotation, the assumption is that the map
            // is already rotated properly when this function is called

            topLeftCoordinate = mapView.mapboxMap.coordinate(for: CGPoint(
                x: centerPoint.x - syncSquareSize / 2,
                y: centerPoint.y - syncSquareSize / 2
            ))

            bottomRightCoordinate = mapView.mapboxMap.coordinate(for: CGPoint(
                x: centerPoint.x + syncSquareSize / 2,
                y: centerPoint.y + syncSquareSize / 2
            ))
        }

        topLeftSyncViewAnnotation.annotatedFeature = .geometry(Point(topLeftCoordinate))
        bottomRightSyncViewAnnotation.annotatedFeature = .geometry(Point(bottomRightCoordinate))
    }

    /// Remove the mapbox annotation views for driving mapbox -> pdf sync and stop observing
    private func tearDownSyncAnnotationViews() {
        bottomRightSyncAnnotationViewObservation?.invalidate()

        topLeftSyncViewAnnotation?.remove()
        topLeftSyncViewAnnotation = nil
        bottomRightSyncViewAnnotation?.remove()
        bottomRightSyncViewAnnotation = nil
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
    func animatePanAndZoom(cameraCenter: CLLocationCoordinate2D, mapboxZoom: Double, completion: (() -> Void)? = nil) {
        setFollowMeMode(enabled: false)
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
                completion?()
            }
            animator.startAnimation()
        }
    }

    /// Calculate and apply PDF offset and zoom based on the sync driving annotation views
    /// The calculations are based only on screen coordinates as the annotations were placed so their centers
    /// match the top-left and bottom-right corners of the PDF, so the PDF scale and offset can be inferred directly
    /// from current on screen positions of the annotation views, without doing any mapbox camera/zoom or geocoordinates calculations.
    ///
    /// Good article on how iOS UIScrollView works: https://www.objc.io/issues/3-views/scroll-view/
    private func syncPDFViewWithAnnotationViews() {
        guard let pdfScrollView = pdfScrollView,
              let topLeftCenter = topLeftSyncViewAnnotation?.view.center,
              let bottomRightCenter = bottomRightSyncViewAnnotation?.view.center,
              canvas.currentCanvasSource.type == .pdf else { return }

        let syncViewsDistanceSquared = CGPointDistanceSquared(from: topLeftCenter, to: bottomRightCenter)
        guard syncViewsDistanceSquared > 0 else { return }
        // scale the PDF linearly with the sync square ( = syncViewsDistance / syncSquareSize*sqrt(2) <- initial distance
        let pdfScale = sqrt(syncViewsDistanceSquared / 2.0) / syncSquareSize

        let syncViewsCenter = CGPoint(
            x: (topLeftCenter.x + bottomRightCenter.x) / 2,
            y: (topLeftCenter.y + bottomRightCenter.y) / 2
        )
        let xOffset = -(syncViewsCenter.x - pdfScrollView.center.x * pdfScale)
        let yOffset = -(syncViewsCenter.y - pdfScrollView.center.y * pdfScale)
        
        // the rotation is based on the initial canvas source rotation, so the pdf is not rotated
        // when the map bearing = canvasSource.rotation (that's the initial state when loading canvas source)
        let pdfRotation = canvas.currentCanvasSource.rotation - mapView.mapboxMap.cameraState.bearing
        
        pdfScrollView.zoomScale = pdfScale
        pdfScrollView.contentOffset = CGPoint(x: xOffset, y: yOffset)
        // The rotation needs to be applied to the pdfView.
        // - cannot be applied to pdfScrollView 
        //      - that would make the offset/zoom calculations much more complicated
        // - cannot be applied to pdfScrollView.contentView (parent view of pdfView)
        //      - scroll view controls it's transformation to support zoomScale
        pdfScrollView.pdfView.transform = CGAffineTransformMakeRotation(_deg2rad(pdfRotation))
    }

    func setFollowMeMode(enabled: Bool) {
        if enabled {
            // enable mapbox viewport managed follow puck mode
            let state = mapView.viewport.makeFollowPuckViewportState(
                // don't update zoom, bearing or pitch based on blue dot
                options: FollowPuckViewportStateOptions(zoom: nil, bearing: nil, pitch: nil)
            )
            mapView.viewport.transition(to: state)
        } else {
            // back to idle mode
            mapView.viewport.idle()
        }
    }
}

/// Delegate for Mapbox driving gestures
extension CanvasViewController: GestureManagerDelegate {
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
extension CanvasViewController {
    /// Recognize taps in the pdf view or mapView, translate to mapbox view and forward to delegates using canvasTapRecognized.
    @objc func didTapCanvasView(_ sender: UITapGestureRecognizer) {
        let point = sender.location(in: sender.view)
        guard let pointInMapView = sender.view?.convert(point, to: mapView) else { return }
        delegates.values.forEach {
            $0.canvasTapRecognized(at: pointInMapView)
        }
    }

    @objc func didLongPressCanvasView(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: gesture.view)
        guard let pointInMapView = gesture.view?.convert(point, to: mapView) else { return }
        delegates.values.forEach {
            $0.canvasLongPressRecognized(at: pointInMapView)
        }
    }
}
