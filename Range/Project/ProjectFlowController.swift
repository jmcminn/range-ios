import Combine
import OSLog
import Realm
import RealmSwift
import SnapKit
import SwiftUI
import UIKit

/// Protocol defining actions that project flow can perform.
/// Required by the views sending actions, so they can use selectors for these functions.
/// See https://swiftrocks.com/understanding-the-ios-responder-chain.html for more info
@objc protocol ProjectFlowActions: AnyObject {
    /// show the Media card view controller with all project uploads
    func showMediaAction()
    /// Select and change the current canvas for project
    func selectCanvasAction()
}

/// Main view controller for displaying a project.
/// It manages the UI state of project and all view transitions.
final class ProjectFlowController: UIViewController, ProjectFlowActions {
    unowned let imageCaches: ImageCaches
    let model: ProjectModel
    let modelFirestoreSync: ProjectModelFirestoreSync

    let canvasContainer: CanvasContainerViewController
    let collaborationFlow: CollaborationFlowController

    let debugSettings = DebugSettings()
    /// for storing the debugSettings observer(s)
    private var debugSettingsNativeViewsForPinsSubscriber: AnyCancellable?

    var topViewController: ProjectTopViewController?
    lazy var bottomBlurView = setupBottomBlur()
    lazy var actionCardVC = setupActionCardVC()
    var pinsDisplay: GeometriesPinsDisplay?
    var canvasSelectorButton: RoundShadowButton!

    /// To observed changes in model.currentCanvas
    private var canvasObservation: NSKeyValueObservation?

    /// id of registered canvas delegate
    var canvasDelegateId: UUID?

    /// throttle the presence reporting when canvas camera changes, report no more frequently than every 0.5 seconds
    var reportPresenceThrottler = Throttler(throttleTime: 0.5)

    var addPhotoFlow: AddPhotoFlowController?

    var started = false
    var onBack: (() -> Void)?

    /// Initialize ProjectFlowController
    /// This can throw if project model cannot be loaded or started
    ///
    /// - Parameters:
    ///     - userId: range id of the logged in user
    ///     - projectId: id of the project
    ///     - canvasId: id of the canvas, if not provided then load the 1st canvas in a project
    init(
        userId: String,
        projectId: String,
        canvasId: String?,
        imageCaches: ImageCaches,
        pendingUploadsModel: PendingUploadsModel,
        pendingActionsModel: PendingActionsModel
    ) async throws {
        self.imageCaches = imageCaches
        model = try ProjectModel(
            userId: userId,
            projectId: projectId,
            imageCaches: imageCaches,
            pendingUploadsModel: pendingUploadsModel,
            pendingActionsModel: pendingActionsModel
        )
        try await model.start()

        modelFirestoreSync = ProjectModelFirestoreSync(model: model)
        await modelFirestoreSync.start()

        do {
            try model.loadProject(initialCanvasId: canvasId)
        } catch {
            if canvasId != nil {
                // failed to load some canvas, try the default one
                Logger.model.info("failed to load canvas \(canvasId) for project \(projectId). Try the default canvas.")
                try model.loadProject(initialCanvasId: nil)
            } else {
                throw error
            }
        }

        canvasContainer = try await CanvasContainerViewController(model: model)
        collaborationFlow = CollaborationFlowController(
            model: model,
            imageCaches: imageCaches,
            canvasContainer: canvasContainer
        )

        super.init(nibName: nil, bundle: nil)

        collaborationFlow.onCollaborationClose = { [weak self] in
            // unselect pin, this will result also in hiding the collaboration window
            self?.pinsDisplay?.setSelectedPin(nil)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Only start the flow controller (add all the subviews, etc.) when the layout has completed to properly calculate all the
    /// views/cards sizes
    override func viewDidLayoutSubviews() {
        start()
    }

    private func start() {
        guard started == false else { return }
        started = true
        createGeometriesPinsDisplay(useNativeViews: debugSettings.nativeViewsForPins)
        add(childController: canvasContainer)
        canvasContainer.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        canvasContainer.view.setNeedsLayout()
        canvasContainer.view.layoutIfNeeded()
        showTopViewController(animated: false)
        bottomBlurView.isHidden = false

        setupCanvasSelectorButton()

        showDefaultCanvasUI(animated: false)
        collaborationFlow.start()
        observeDebugSettings()

        canvasObservation = model.observe(\.currentCanvas) { [weak self] _, _ in
            guard let self = self else { return }
            self.reloadGeometriesPinsDisplay(useNativeViews: self.debugSettings.nativeViewsForPins)
        }

        canvasDelegateId = canvasContainer.pdfCanvasViewController.addDelegate(self)
    }

    /// Reload the geometries pins display.
    /// It stops the current pins display, creates a new one and starts it if the previous one was started (maybe it was temporarily stopped,
    /// then we need the new one to be stopped too)
    private func reloadGeometriesPinsDisplay(useNativeViews: Bool) {
        let start = pinsDisplay?.started ?? false
        pinsDisplay?.stop()
        createGeometriesPinsDisplay(useNativeViews: useNativeViews)
        if start {
            pinsDisplay?.start(onInitialLoad: nil)
        }
    }

    private func observeDebugSettings() {
        debugSettingsNativeViewsForPinsSubscriber = debugSettings.$nativeViewsForPins
            .sink { [weak self] useNativeViews in
                self?.reloadGeometriesPinsDisplay(useNativeViews: useNativeViews)
            }
    }

    private func createGeometriesPinsDisplay(useNativeViews: Bool) {
        pinsDisplay = useNativeViews
            ? GeometriesViewAnnotationPinsDisplay(
                canvas: model.currentCanvas,
                canvasViewController: canvasContainer.pdfCanvasViewController,
                deselectOnCanvasTap: true,
                geometryPinDisplayOptionsProvider: PinDisplayOptions.regularPinDisplayOptionsProvider
            )
            : GeometriesAnnotationPinsDisplay(
                canvas: model.currentCanvas,
                canvasViewController: canvasContainer.pdfCanvasViewController,
                deselectOnCanvasTap: true,
                geometryPinDisplayOptionsProvider: PinDisplayOptions.regularPinDisplayOptionsProvider
            )
        pinsDisplay?.onSelectedPinChange = { [weak self] pinPoint in
            if let geometryId = pinPoint?.id {
                // minimize the action card when showing collab
                self?.actionCardVC.cardDragging?.setPosition(.min, withVelocity: 0, animated: true)
                self?.collaborationFlow.showCollaborationWindow(forGeometry: geometryId, animated: true)
            } else {
                self?.collaborationFlow.hideCollaborationWindow(animated: true)
            }
        }
    }

    func stop() {
        collaborationFlow.stop()
        pinsDisplay?.stop()
        if let canvasDelegateId = canvasDelegateId {
            canvasContainer.pdfCanvasViewController.removeDelegate(id: canvasDelegateId)
        }
        canvasContainer.removeCard(cardViewController: actionCardVC)
        remove(childController: canvasContainer)
        debugSettingsNativeViewsForPinsSubscriber?.cancel()
        debugSettingsNativeViewsForPinsSubscriber = nil
        canvasObservation?.invalidate()
        canvasObservation = nil
    }

    /// shows the view controller covering the top of of the screen
    private func showTopViewController(animated: Bool) {
        let topViewController = ProjectTopViewController(projectSummary: model.projectSummary)
        topViewController.onBack = onBack
        canvasContainer.add(childController: topViewController, toView: canvasContainer.controls)
        if animated {
            topViewController.view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.bottom.equalTo(canvasContainer.controls.snp.top)
            }
            canvasContainer.controls.layoutIfNeeded()
            UIView.animate(withDuration: 0.2) {
                topViewController.view.snp.remakeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.top.equalToSuperview()
                }
                self.canvasContainer.controls.layoutIfNeeded()
            }
        } else {
            topViewController.view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.equalToSuperview()
            }
            canvasContainer.controls.layoutIfNeeded()
        }
        self.topViewController = topViewController
    }

    /// hides the top view controller
    private func hideTopViewController() {
        if let topViewController = topViewController {
            UIView.animate(withDuration: 0.2) {
                topViewController.view.snp.remakeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.bottom.equalTo(self.canvasContainer.controls.snp.top)
                }
                self.canvasContainer.controls.layoutIfNeeded()
            }
        }
    }

    /// Show the default UI elements when viewing the canvas
    fileprivate func showDefaultCanvasUI(animated: Bool = true) {
        actionCardVC.showCard(animated: animated)
        canvasSelectorButton.isHidden = false
        pinsDisplay?.start(onInitialLoad: nil)
    }

    /// Hide the default UI elements when viewing the canvas
    fileprivate func hideDefaultCanvasUI(animated: Bool = true) {
        actionCardVC.hideCard(animated: animated)
        canvasSelectorButton.isHidden = true
        pinsDisplay?.stop()
    }

    fileprivate func setupCanvasSelectorButton() {
        canvasSelectorButton = RoundShadowButton(image: UIImage(systemName: "square.3.layers.3d") ?? UIImage())
        canvasSelectorButton.addTarget(self, action: #selector(selectCanvasAction), for: .touchUpInside)
        canvasContainer.controls.addSubview(canvasSelectorButton)
        canvasSelectorButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.bottom.equalTo(actionCardVC.view.snp.top).offset(-12)
        }
    }

    /// Shows view controller for debug settings
    @objc func showDebugSettingsAction() {
        let debugSettingsVC = UIHostingController(
            rootView: DebugSettingsView().environmentObject(debugSettings)
        )
        present(debugSettingsVC, animated: true)
    }

    fileprivate func setupBottomBlur() -> UIView {
        let blur = UIBlurEffect(style: .regular)
        let blurView = UIVisualEffectView(effect: blur)
        canvasContainer.overlays.addSubview(blurView)
        blurView.snp.makeConstraints { [weak self] make in
            guard let self = self else { return }
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(self.view.safeAreaInsets.bottom)
        }
        return blurView
    }

    fileprivate func setupActionCardVC() -> ProjectActionCardViewController {
        // TODO: 704 this should be hidden in the production version
        let additionalCardActions = [
            ActionItem(
                title: "Toggle Light/Dark mode",
                imageName: "lightbulb",
                handler: { [weak self] in
                    guard let self = self else { return }
                    self.view.window?.overrideUserInterfaceStyle = self.traitCollection
                        .userInterfaceStyle == .dark ? .light : .dark
                }
            ),
            ActionItem(
                title: "Show dev settings",
                imageName: "gearshape",
                handler: { [weak self] in
                    self?.showDebugSettingsAction()
                }
            ),
        ]
        let vc = ProjectActionCardViewController(actions: additionalCardActions)
        vc.onCamera = { [weak self] in
            self?.startAddPhotoFlow()
        }
        vc.onAddMarker = { [weak self] in
            self?.addMarker()
        }

        canvasContainer.installCard(cardViewController: vc,
                                    inView: canvasContainer.controls,
                                    cardConfig: CardConfiguration(linkedViewToLayout: canvasContainer.controls))
        return vc
    }
}

// MARK: - canvas delegate

extension ProjectFlowController: CanvasViewControllerDelegate {
    func canvasCameraChanged(reason: CanvasCameraChangeReason) {
        if reason == .panEnd || reason == .zoomEnd || reason == .programmatic {
            reportPresenceThrottler.throttle { [weak self] in
                self?.reportPresence()
            }
        }
    }

    func canvasTapRecognized(at _: CGPoint) {}
}

// MARK: - actions

extension ProjectFlowController {
    /// Reports the current canvas and position so it can be displayed on other devices
    private func reportPresence() {
        let coordinates = canvasContainer.annotationsMapView.cameraState.center
        modelFirestoreSync.reportPresence(coordinates: coordinates)
    }

    private func startAddPhotoFlow() {
        addPhotoFlow = AddPhotoFlowController(model: model, imageCaches: imageCaches, canvasContainer: canvasContainer)
        addPhotoFlow?.onStop = { [weak self] in
            self?.showDefaultCanvasUI()
            self?.addPhotoFlow = nil
        }
        addPhotoFlow?.start { [weak self] started in
            // hide cards if photo flow started
            if started {
                self?.hideDefaultCanvasUI()
            } else {
                self?.addPhotoFlow = nil
            }
        }
    }

    private func addMarker() {
        ActionSelectorCardViewController(
            icon: UIImage(systemName: "mappin.and.ellipse"),
            title: String(localized: "Add Marker"),
            actions: [
                ActionItem(
                    title: String(localized: "Photo Collection"),
                    imageName: "photo",
                    handler: {}
                ),
                ActionItem(
                    title: String(localized: "Issue"),
                    imageName: "checkmark.circle",
                    handler: {}
                ),
            ]
        ).installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    func selectCanvasAction() {
        let canvases = [PDFCanvas](model.mainRealm.objects(PDFCanvas.self).sorted(by: \PDFCanvas.pageNumber))
        CanvasSelectorCardViewController(
            title: String(localized: "Source Selector"),
            canvases: canvases,
            selectedCanvas: model.currentCanvas,
            onCanvasSelected: { [weak self] canvas in
                guard let self = self else { return }
                guard self.model.currentCanvas != canvas else { return }
                self.model.currentCanvas = canvas
            }
        ).installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    func showMediaAction() {
        MediaCardViewController(
            projectModel: model,
            imageCaches: imageCaches,
            title: String(localized: "Media"),
            uploads: model.mainRealm.objects(Upload.self).where
                { $0.placeholder == false && $0.fileType == .image },
            onUploadSelected: { _ in
            }
        ).installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }
}
