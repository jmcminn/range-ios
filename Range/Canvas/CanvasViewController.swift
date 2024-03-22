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

/// Displays a mapbox map view for canvas.
///
/// - For PDF canvas sources it shows the PDF view behind the map view (with an empty style so there's no map visible).  In this case
/// the mapbox map is receiving the user interactions and controls the PDF zoom/offset.
///
/// - For mapbox and drone deploy sources it just displays the style defined in the source.
class CanvasViewController: UIViewController {
    let maxMapboxZoom = 25.5

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

    unowned let model: ProjectModel
    unowned let canvasFileLoader: CanvasFileLoader
    private var canvas: Canvas
    // only when displaying pdf source
    private var pdfPage: PDFPage?

    /// Mapbox for rendering the background mapview for .mapbox and .dronedeploy sources and for rendering the pins for all sources
    /// Achtung: reloading mapView instance when switching sources is not supported now. So when switching sources the initial
    /// mapView instance needs to be used instead of creating a new one, because pins are already added to it, and are only reloaded
    /// if the canvas changes. If we wanted to reload map view on canvas/canvasSource change we would need to "notify" pins to reload
    /// **after** the new mapView instance is created.
    private(set) var mapView: MapView!
    /// view shown behind the pdf view
    var gridView: GridView?
    var pdfScrollView: PDFPageScrollView?
    var initialPdfScale: Double!

    /// Remember the camera state when switching canvas sources. A dictionary of CanvasSource.id => CameraState
    private var cameraStateCache = [String: CameraState]()

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

        if canvas.currentCanvasSource.type == .pdf {
            try await reloadPdfPage()
        }
        observeCurrentCanvasSource()
        observeCanvasSourceChanges()
        currentCanvasObservation = model.observe(\.currentCanvas) { [weak self] _, _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.onCanvasChange()
            }
        }
    }

    private let screenshotAreaView = UIView()
    private var mapSnapshotter: Snapshotter?

    // TODO: 2560 move to Canvas Screenshotter
    // TODO: 2560 viewport parameter?
    func takeScreenshot() async throws -> UIImage {
        // TODO: 2560 this should be handled by CanvasScreenshotSelectionVC
        if screenshotAreaView.superview == nil {
            screenshotAreaView.isUserInteractionEnabled = false
            screenshotAreaView.layer.cornerRadius = 8
            view.addSubview(screenshotAreaView)
            screenshotAreaView.snp.makeConstraints { make in
                make.center.width.equalToSuperview()
                make.height.equalTo(screenshotAreaView.snp.width).multipliedBy(0.75)
            }
            view.layoutIfNeeded()
        }

        if canvas.currentCanvasSource.type == .pdf {
            guard let page = pdfPage, let pdfView = pdfScrollView?.pdfView else {
                throw "pdf page or view missing foc pdf canvas source"
            }

            // this gives the part of the pdf view visible inside the screenshotArea
            // it's all in pdfView units (not in the pdf page coordinates)
            let screenshotViewBoundsInPdfViewCoordinates = screenshotAreaView.convert(
                screenshotAreaView.bounds,
                to: pdfView
            )
            // the size reported by the PDF page (unrelated to view rendering)
            let pageBounds = page.bounds(for: .mediaBox)
            // pdf page size to the rendered view ratio
            let pageBoundsToViewFrameRatio = pageBounds.width / pdfView.frame.width
            // selection bounds in the coordinates of the page bounds (in PDF units, unrelated to view rendering)
            let selectionBounds = CGRect(
                x: screenshotViewBoundsInPdfViewCoordinates.origin.x * pageBoundsToViewFrameRatio,
                y: screenshotViewBoundsInPdfViewCoordinates.origin.y * pageBoundsToViewFrameRatio,
                width: screenshotViewBoundsInPdfViewCoordinates.width * pageBoundsToViewFrameRatio,
                height: screenshotViewBoundsInPdfViewCoordinates.height * pageBoundsToViewFrameRatio
            )
            // Scale from the pdf selection bounds size to the expected image size
            // If pdf selection is 400x300 but we want a 4096px wide image then scale is 10.24 (4096/400)
            // This is needed to render images in constant resolution and not depending on the
            // size (in PDF units) of selected PDF are
            let scale = 4096.0 / max(selectionBounds.width, selectionBounds.height)
            let imageSize = CGSize(
                width: selectionBounds.size.width * scale,
                height: selectionBounds.size.height * scale
            )
            let renderer = UIGraphicsImageRenderer(
                size: imageSize,
                // keep the original scale (changing the scale here would change the image resolution):
                format: UIGraphicsImageRendererFormat(for: UITraitCollection(displayScale: 1))
            )
            let img = renderer.image { ctx in
                UIColor.white.set()
                // fill the background
                ctx.fill(CGRect(origin: .zero, size: imageSize))

                // PDF has (0,0) in the bottom left
                ctx.cgContext.translateBy(
                    x: scale * -selectionBounds.origin.x, // offset according to selection offset
                    y: scale * (-selectionBounds.origin.y + pageBounds.height) // offset
                )
                // -1 for y and a special offset above (pageBounds.height) are to mirror the PDF
                ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                // match the img scale
                ctx.cgContext.scaleBy(x: scale, y: scale)

                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            return img
        } else {
            // the size for mapbox snapshot must match the area to be snapshotted size
            // If the size is bigger it just snapshots a wider area
            // We can make it better quality by specifying the pixelRatio

            // -------------------------------------------------------------------------------------
            // Snapshot size vs pixelRatio.
            // screenshotAreaView is quite small in points.
            // If we want the screenshot with given size (4096x3072), we have 2 options:
            // 1. use the screenshotAreaView with current camera zoom level and adjust the
            //    pixelRatio to make the final image resolution higher
            //    - this works but takes the screenshot at a zoom level where the details
            //      are suited for screenshotAreaView size, so making it more dense doesn't help much,
            //      it only makes the roads, names higher res
            // 2. Adjust the size to be 4096x3072, at the same time adjust the camera zoom (zoom in),
            //    so it still shows the same real world bounds. So we just pretend we're on a bigger
            //    screen.
            //    - this will render a different zoom level tiles, but the end image will be really
            //      in higher "real map" resolution
            //    - the drawback is that it's not actually rendering the tiles user sees when taking
            //      screenshot, but potentially switches to a higher-res tiles level
            //    - when doing this procedure, we need to limit this procedure to the max mapbox zoom
            //      level, so in fact it'll be a mix of (2) and (1) if max level is reached

            let snapshotSize: CGSize
            let snapshotZoom: CGFloat

            let useOption1 = false
            // option 1
            if useOption1 {
                snapshotSize = screenshotAreaView.frame.size
                snapshotZoom = mapView.mapboxMap.cameraState.zoom
            } else {
                let expectedZoomIn = min(
                    // TODO: 2560 limit the zoom in??
                    CGFloat(_debugSettings.mapboxCanvasSnapshotZoomInFactor),
                    4096 / max(
                        screenshotAreaView.frame.width,
                        screenshotAreaView.frame.height
                    )
                )

                // current zoom observed by user when taking the screenshot
                let initialZoom = mapView.mapboxMap.cameraState.zoom
                // adjust the current zoom to make it * expectedZoomIn. We cannot just
                // mulitply as mapbox zoom is exponential, so we convert to a linear
                // value, multiply and convert back
                let initialMetersPerPoint = zoomConverter.getMetersPerPoint(forZoom: initialZoom)
                // we want to zoom in * expectedZoomIn, so we want less metersPerPoint
                let expectedMetersPerPoint = initialMetersPerPoint / expectedZoomIn
                let expectedZoom = zoomConverter.getZoom(forMetersPerPoint: expectedMetersPerPoint)

                snapshotZoom = min(expectedZoom, maxMapboxZoom)
                print(
                    "XXX camera zoom \(initialZoom) '*' \(expectedZoomIn) = \(expectedZoom), allowed = \(snapshotZoom)"
                )

                // if we applied the maxMapboxZoom we need to go back to calculate the snapshotSize
                // we get from zooming in (if not we can still do it)
                let allowedMetersPerPoint = zoomConverter.getMetersPerPoint(forZoom: snapshotZoom)
                let allowedZoomIn = initialMetersPerPoint / allowedMetersPerPoint

                snapshotSize = CGSize(
                    width: screenshotAreaView.frame.size.width * allowedZoomIn,
                    height: screenshotAreaView.frame.size.height * allowedZoomIn
                )
            }
            let snapshotPixelRatio = 4096 / max(
                snapshotSize.width,
                snapshotSize.height
            )
            let snapshotOptions = MapSnapshotOptions(
                size: snapshotSize, pixelRatio: snapshotPixelRatio,
                showsLogo: false, showsAttribution: false
            )
            print("XXX ", snapshotOptions, snapshotZoom)
            var cameraOptions = CameraOptions(cameraState: mapView.mapboxMap.cameraState)
            cameraOptions.zoom = snapshotZoom
            mapSnapshotter = Snapshotter(options: snapshotOptions)

            return try await withCheckedThrowingContinuation { continuation in
                mapSnapshotter?._loadMapboxStyle(forCanvasSourceData: canvas.currentCanvasSource.data) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        self.mapSnapshotter?.setCamera(to: cameraOptions)
                        self.mapSnapshotter?.start(overlayHandler: nil) { result in
                            switch result {
                            case let .success(image): continuation.resume(returning: image)
                            case let .failure(error): continuation.resume(throwing: error)
                            }
                        }
                    }
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        // initiate mapview
        setupMapView()

        // setup annotation views
        setupSyncAnnotationViews()

        // update the style, etc. for current canvas/source
        updateMapViewForCanvasSource()

        // setup scroll view with given pdf page (if it's a pdf source)
        setupPDFScrollView()

        // this needs to be done after pdf view was set up as the zoom logic for pdfs is based on
        // pdf frame size
        updateCameraForCanvasSource()

//        setupDebugViews()
    }

    /// Canvas was changed, reload the canvas view
    private func onCanvasChange() async {
        guard canvas.id != model.currentCanvas.id else { return }
        let previousCanvas = canvas
        canvas = model.currentCanvas
        setFollowMeMode(enabled: false)
        observeCurrentCanvasSource()
        observeCanvasSourceChanges()
        await onCanvasSourceChange(previousCanvasSource: previousCanvas.currentCanvasSource)
    }

    /// Canvas source changed, reload the view
    private func onCanvasSourceChange(previousCanvasSource: CanvasSource) async {
        // store the camera state so it can be reused when switching back to same canvas source
        cameraStateCache[previousCanvasSource.id] = mapView.mapboxMap.cameraState
        let fromPdfToPdf = previousCanvasSource.type == .pdf && canvas.currentCanvasSource.type == .pdf
        if !fromPdfToPdf {
            // if switching from pdf to other pdf the map view remains the same (empty style and configuration for pdf background)
            updateMapViewForCanvasSource()
        }
        if canvas.currentCanvasSource.type == .pdf {
            do {
                try await reloadPdfPage()
            } catch {
                let sourceId = canvas.currentCanvasSource.id
                Logger.model.error(
                    "Failed to load pdf for canvas source \(sourceId, privacy: .public), \(error.localizedDescription, privacy: .public)"
                )
                ToastWindow.shared.showError(text: "Canvas failed to load")
            }
            setupPDFScrollView()
            updateCameraForCanvasSource()
        } else {
            updateCameraForCanvasSource()
            gridView?.removeFromSuperview()
            gridView = nil
            pdfScrollView?.removeFromSuperview()
            pdfScrollView = nil
        }
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
                    await self.onCanvasSourceChange(previousCanvasSource: previousCanvasSource)
                }
            }
    }

    /// Observe when canvas source is updated
    private func observeCanvasSourceChanges() {
        canvasSourceNotificationToken?.invalidate()
        if case .pdf = canvas.currentCanvasSource.data {
            // observe pdf source for storage version (or any) update to reload the pdf
            self.canvasSourceNotificationToken = self.canvas.currentCanvasSource.observe { [weak self] _ in
                Task { @MainActor in
                    // update the pdfCanvas
                    await self?.reloadPDFScrollView()
                }
            }
        }
    }

    /// This is called when canvas PDF changes after loading the initial canvas.
    /// We keep the zoom/offset, so there's no recalculation of initial zoom.
    @MainActor
    private func reloadPDFScrollView() async {
        guard !canvas.isInvalidated else { return }
        // first hide the previous pdf view
        gridView?.removeFromSuperview()
        gridView = nil
        pdfScrollView?.removeFromSuperview()
        pdfScrollView = nil

        guard canvas.currentCanvasSource.type == .pdf else { return }

        do {
            // load the page
            try await reloadPdfPage()
            // build new view
            setupPDFScrollView()
            // sync with current zoom/offset from mapbox
            syncPDFViewWithAnnotationViews()
        } catch {
            Logger.model.error("load canvas error: \(error.localizedDescription, privacy: .public)")
            ToastWindow.shared.showError(text: "Failed to load the canvas")
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
        gridView?.removeFromSuperview()
        gridView = nil
        pdfScrollView?.removeFromSuperview()
        pdfScrollView = nil

        guard canvas.currentCanvasSource.type == .pdf else { return }

        guard let pdfPage = pdfPage else {
            fatalError("setupPDFScrollView called when pdfPage is nil")
        }

        gridView = GridView(frame: view.bounds)
        view.insertSubview(gridView!, at: 0)

        let pdfScrollView = PDFPageScrollView(frame: view.bounds, pdfPage: pdfPage)
        view.insertSubview(pdfScrollView, at: 1)
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

        let pdfMetersPerPoint = getInitialMetersPerPointForPdf()
        let initialMapboxMetersPerPoint = zoomConverter.getMetersPerPoint(forZoom: initialMapboxZoom)
        initialPdfScale = pdfMetersPerPoint / initialMapboxMetersPerPoint
    }

    /// Returns the center for the current canvas source.
    /// - for pdf it uses the project center
    /// - otherwise it uses the zoom defined in the canvas source
    private func getCenterForCurrentCanvasSource() -> CLLocationCoordinate2D {
        switch canvas.currentCanvasSource.data {
        case .pdf:
            return model.projectSummary.center
        case let .mapbox(mapboxData):
            return mapboxData.center.decodedCoordinates
        case let .droneDeploy(droneDeployData):
            return droneDeployData.center.decodedCoordinates
        }
    }

    /// Based on the pdf properties and current pdf view size calculate what's the ratio of real world meters per screen point for pdf
    private func getInitialMetersPerPointForPdf() -> Double {
        guard case let .pdf(pdfData) = canvas.currentCanvasSource.data else {
            fatalError("getInitialMetersPerPointForPdf called when canvas source is not pdf")
        }
        guard let pdfPage = pdfPage else {
            fatalError("getInitialMetersPerPointForPdf called when pdfPage is nil")
        }
        let pdfSizeInMeters = pdfPage.sizeInMeters(forScale: 1.0 / pdfData.userDefinedScale)
        let pdfWidthMetersPerPoint = pdfSizeInMeters.width / view.bounds.width
        let pdfHeightMetersPerPoint = pdfSizeInMeters.height / view.bounds.height
        let initialMetersPerPoint = max(pdfWidthMetersPerPoint, pdfHeightMetersPerPoint)
        return initialMetersPerPoint
    }

    /// Returns the zoom based on the current canvas/canvasSource
    /// - for pdf it matches the zoom scale of PDFPage when it fits the view
    /// - otherwise it uses the zoom defined in the source
    private func getZoomForCurrentCanvasSource() -> Double {
        switch canvas.currentCanvasSource.data {
        case .pdf:
            let initialMetersPerPoint = getInitialMetersPerPointForPdf()
            /// Initial mapbox zoom matching the pdf page fitting the view
            return zoomConverter.getZoom(forMetersPerPoint: initialMetersPerPoint)
        case let .mapbox(mapboxData):
            return mapboxData.zoom
        case let .droneDeploy(droneDeployData):
            return droneDeployData.zoom
        }
    }

    // initial setup of map view
    private func setupMapView() {
        guard mapView == nil else {
            fatalError("setupMapView called when mapView is not nil")
        }
        // set initial mapbox zoom level and position
        let cameraOptions = CameraOptions(
            //            center: getCenterForCurrentCanvasSource(),
//            zoom: getZoomForCurrentCanvasSource()
            center: model.projectSummary.center,
            zoom: initialMapboxZoom
        )
        mapView = MapView(
            frame: view.bounds,
            mapInitOptions: MapInitOptions(cameraOptions: cameraOptions)
        )

        do {
            try mapView.mapboxMap.setCameraBounds(with: CameraBoundsOptions(maxZoom: maxMapboxZoom))
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
            // rotations and pitch change is not supported for PDF
            mapView.gestures.options.rotateEnabled = false
            mapView.gestures.options.pitchEnabled = false
        } else {
            mapView.subviews.forEach { subview in
                if subview is MTKView {
                    subview.isOpaque = true
                }
            }
            mapView.gestures.options.rotateEnabled = true
            mapView.gestures.options.pitchEnabled = true
        }

        mapView.mapboxMap._loadMapboxStyle(forCanvasSourceData: canvas.currentCanvasSource.data)

        if canvas.currentCanvasSource.type == .pdf {
            // no location support
            mapView.location.options.puckType = nil
        } else {
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
        }
    }

    /// resets the camera for given canvas source
    private func updateCameraForCanvasSource() {
        let cameraState = cameraStateCache[canvas.currentCanvasSource.id]
            ?? CameraState(
                center: getCenterForCurrentCanvasSource(),
                padding: .zero,
                zoom: getZoomForCurrentCanvasSource(),
                bearing: 0,
                pitch: 0
            )
        mapView.mapboxMap.setCamera(to: CameraOptions(cameraState: cameraState))
    }

    /// Add special mapbox annotation views that are transparent and act as a map -> pdf sync driver. Does nothing when canvas source is not pdf.
    /// These are just to special annotations placed in the top left and bottom right corners of a square that has a side length = `syncSquareSize` points (in screen coordiantes)
    /// and is centered at the mapView center
    private func setupSyncAnnotationViews() {
        // this is the size in screen coordiantes. It needs to be very big as mapbox only tracks
        // annotations that are currently on screen. Such big size guarantess that no matter
        // what zoom and center this annotation view is partially on screen (but still not visible
        // as it's an empty view with alpha = 0)
        let annotationViewSize = CGSize(width: 100_001, height: 100_001)

        let topLeft = UIView(frame: CGRect(origin: .zero, size: annotationViewSize))
        topLeft.backgroundColor = .clear
        let topLeftViewAnnotation = ViewAnnotation(coordinate: mapView.mapboxMap.coordinate(for: CGPoint(
            x: mapView.center.x - syncSquareSize / 2,
            y: mapView.center.y - syncSquareSize / 2
        )), view: topLeft)
        topLeftViewAnnotation.allowOverlap = true
        topLeftViewAnnotation.allowOverlapWithPuck = true
        mapView.viewAnnotations.add(topLeftViewAnnotation)
        topLeftSyncViewAnnotation = topLeftViewAnnotation

        let bottomRight = UIView(frame: CGRect(origin: .zero, size: annotationViewSize))
        bottomRight.backgroundColor = .clear
        let bottomRightViewAnnotation = ViewAnnotation(coordinate: mapView.mapboxMap.coordinate(for: CGPoint(
            x: mapView.center.x + syncSquareSize / 2,
            y: mapView.center.y + syncSquareSize / 2
        )), view: bottomRight)
        bottomRightViewAnnotation.allowOverlap = true
        bottomRightViewAnnotation.allowOverlapWithPuck = true
        mapView.viewAnnotations.add(bottomRightViewAnnotation)

        bottomRightSyncViewAnnotation = bottomRightViewAnnotation

        // show topLeft/bottomRight dots to help debug
//            let dotFrame = CGRect(origin: CGPoint(x: 50000 - 3, y: 50000 - 3), size: CGSize(width: 7, height: 7))
//            let topLeftDot = UIView(frame: dotFrame)
//            topLeftDot.layer.cornerRadius = 3.5
//            topLeftDot.backgroundColor = .Red_03
//            topLeft.addSubview(topLeftDot)
//            let bottomRightDot = UIView(frame: dotFrame)
//            bottomRightDot.layer.cornerRadius = 3.5
//            bottomRightDot.backgroundColor = .Green_03
//            bottomRight.addSubview(bottomRightDot)

        bottomRightSyncAnnotationViewObservation = bottomRight.observe(\.frame) { [weak self] _, _ in
            self?.syncPDFViewWithAnnotationViews()
        }
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
    private func syncPDFViewWithAnnotationViews() {
        guard let pdfScrollView = pdfScrollView,
              let topLeftCenter = topLeftSyncViewAnnotation?.view.center,
              let bottomRightCenter = bottomRightSyncViewAnnotation?.view.center else { return }

        let syncViewsDistance = bottomRightCenter.x - topLeftCenter.x
        guard syncViewsDistance > 0 else { return }

        // a scale for a view that has scale = 1 when the mapbox zoom is `initialMapboxZoom`
        let referenceScale: CGFloat = syncViewsDistance / syncSquareSize
        // Adjust the reference scale by the pdf scale at reference zoom
        let pdfScale = initialPdfScale * referenceScale
        pdfScrollView.zoomScale = pdfScale

        let syncViewsCenter = CGPoint(
            x: (topLeftCenter.x + bottomRightCenter.x) / 2,
            y: (topLeftCenter.y + bottomRightCenter.y) / 2
        )
        let xOffset = -(syncViewsCenter.x - pdfScrollView.center.x * pdfScale)
        let yOffset = -(syncViewsCenter.y - pdfScrollView.center.y * pdfScale)
        pdfScrollView.contentOffset = CGPoint(x: xOffset, y: yOffset)
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
