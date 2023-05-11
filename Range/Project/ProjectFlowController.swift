import Combine
import Kingfisher
import OSLog
import Realm
import RealmSwift
import SnapKit
import SwiftUI
import UIKit

/// Main view controller for displaying a project.
/// It manages the UI state of project and all view transitions.
final class ProjectFlowController: UIViewController {
    unowned let localFiles: LocalFiles
    unowned let mediaCache: MediaCache
    let model: ProjectModel
    let modelFirestoreSync: ProjectModelFirestoreSync

    let canvasContainer: CanvasContainerViewController
    let collaborationFlow: CollaborationFlowController

    let userSettings: UserSettings
    let debugSettings = DebugSettings()
    /// for storing the debugSettings observer(s)
    private var debugSettingsNativeViewsForPinsSubscriber: AnyCancellable?

    lazy var actionCardVC = setupActionCardVC()
    var pinsDisplay: GeometriesPinsDisplay?
    private let controls: ProjectCanvasControls
    weak var mediaVC: MediaCardViewController?
    weak var fullscreenMediaVC: FullscreenMediaCardViewController?
    weak var taskListVC: TaskListCardViewController?

    /// To observed changes in model.currentCanvas
    private var currentCanvasObservation: NSKeyValueObservation?
    /// Observe the currently selected model.currentCanvas
    private var canvasNotificationToken: NotificationToken?
    /// Token for notifications about changes in the canvas geometries
    private var geometriesNotificationToken: NotificationToken?

    /// id of registered canvas delegate
    var canvasDelegateId: UUID?

    /// throttle the presence reporting when canvas camera changes, report no more frequently than every 0.5 seconds
    var reportPresenceThrottler = Throttler(throttleTime: 0.5)

    /// delay the fading of the canvas indicator view so it doesn't react immediatly to user interaction (so when user performs quick
    /// and short gestures, there will be no fading in between all of them)
    var canvasIndicatorViewFadeDelayer = Delayer(delayTime: 1)

    var addPhotoFlow: AddPhotoFlowController?
    var addPinFlow: AddPinFlowController?
    var movePinFlow: MovePinFlowController?

    var started = false
    /// A Future that gets resolved when the ProjectFlowController is started. Before it's started it makes no sense to call any of it's actions.
    private(set) var startedFuture: Future<Void, Never>?
    /// The promise used internally for resolving the `startedFuture`
    private var startedFuturePromise: Future<Void, Never>.Promise?
    var onBack: (() -> Void)?

    private var defaultCanvasUIHidden = false

    // Canvas filters for this project
    let canvasFilters: CanvasFilters

    /// Arbitrary way of deciding whether user is currently editing the project (so in the middle of some meaningful action that should not
    /// be aborted without confirmation)
    var isUserEditingProject: Bool {
        // some flow is running:
        addPhotoFlow != nil || addPinFlow != nil || movePinFlow != nil
            // any field is editing, so user is in the middle of name update for example:
            || view._firstResponder != nil
            // collaboration says it's being edited:
            || collaborationFlow.isUserEditingCollaboration
            // tags are being edited:
            || canvasContainer.children.contains(where: { $0 is SearchAndSelectTagsViewController })
    }

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
        localFiles: LocalFiles,
        mediaCache: MediaCache,
        pendingUploadsModel: PendingUploadsModel,
        pendingActionsModel: PendingActionsModel,
        userSettings: UserSettings
    ) async throws {
        self.localFiles = localFiles
        self.mediaCache = mediaCache
        model = try ProjectModel(
            userId: userId,
            projectId: projectId,
            localFiles: localFiles,
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
        canvasFilters = UserDefaults.canvasFilters(forProjectId: projectId)
        canvasFilters.model = model

        canvasContainer = try await CanvasContainerViewController(model: model, canvasFilters: canvasFilters)
        collaborationFlow = CollaborationFlowController(
            model: model,
            localFiles: localFiles,
            mediaCache: mediaCache,
            canvasContainer: canvasContainer
        )
        self.userSettings = userSettings
        controls = ProjectCanvasControls(canvasContainer: canvasContainer)

        super.init(nibName: nil, bundle: nil)

        startedFuture = Future { [weak self] promise in
            self?.startedFuturePromise = promise
        }
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

        controls.showTopViewController(title: model.projectSummary.name, onBack: onBack, animated: false)
        updateTopIndicatorView()

        controls.showCanvasSelectorButton(aboveView: actionCardVC.view)
        controls.showCanvasSourceSelectorButton(aboveView: controls.canvasSelectorButton!)
        controls.showCanvasFiltersButton(aboveView: controls.canvasSourceSelectorButton!)
        controls.showCanvasFiltersIndicatorBadge()
        updateFiltersIndicatorBadge()
        // observe the filters and update the filters indicator badge on change
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateFiltersIndicatorBadge),
            name: CanvasFilters.UpdateNotificationName, object: nil
        )
        updateCanvasSourceSelectorVisibility()

        showDefaultCanvasUI(animated: false)
        collaborationFlow.start()
        observeDebugSettings()
        observeCanvas()

        currentCanvasObservation = model.observe(\.currentCanvas) { [weak self] _, _ in
            guard let self = self else { return }
            guard !self.model.currentCanvas.isInvalidated else { return }
            self.updateCanvasSourceSelectorVisibility()
            self.updateTopIndicatorView()
            // observe if the current canvas is removed
            self.observeCanvas()
            self.reloadGeometriesPinsDisplay(
                useNativeViews: self.debugSettings.nativeViewsForPins,
                onReloaded: nil
            )
            self.updateFiltersIndicatorBadge()
        }

        canvasDelegateId = canvasContainer.canvasViewController.addDelegate(self)

        startedFuturePromise?(.success(()))
    }

    private func observeCanvas() {
        geometriesNotificationToken?.invalidate()
        geometriesNotificationToken = model.currentCanvas.pins.observe { [weak self] _ in
            self?.updateFiltersIndicatorBadge()
        }
        canvasNotificationToken?.invalidate()
        canvasNotificationToken = model.currentCanvas.observe { [weak self] change in
            if case .deleted = change {
                // if the currently open canvas is removed just go back to projects
                self?.onBack?()
                ToastWindow.shared.showWarning(text: "Canvas removed")
            }
        }
    }

    /// Reload the geometries pins display.
    /// It stops the current pins display, creates a new one and starts it if the previous one was started (maybe it was temporarily stopped,
    /// then we need the new one to be stopped too)
    func reloadGeometriesPinsDisplay(useNativeViews: Bool, onReloaded: (() -> Void)?) {
        let start = pinsDisplay?.started ?? false
        pinsDisplay?.stop()
        createGeometriesPinsDisplay(useNativeViews: useNativeViews)
        if start {
            pinsDisplay?.start(onInitialLoad: onReloaded)
        }
    }

    private func observeDebugSettings() {
        debugSettingsNativeViewsForPinsSubscriber = debugSettings.$nativeViewsForPins
            .sink { [weak self] useNativeViews in
                guard let self = self else { return }
                self.reloadGeometriesPinsDisplay(useNativeViews: useNativeViews, onReloaded: nil)
            }
    }

    private func createGeometriesPinsDisplay(useNativeViews: Bool) {
        pinsDisplay = _createGeometriesPinsDisplay(
            usingNativeViews: useNativeViews,
            canvas: model.currentCanvas,
            canvasViewController: canvasContainer.canvasViewController,
            deselectOnCanvasTap: true,
            canvasFilters: canvasFilters,
            geometryPinDisplayOptionsProvider: PinDisplayOptions.regularPinDisplayOptionsProvider
        )
        pinsDisplay?.onSelectedPinChange = { [weak self] pinPoint in
            if let geometryId = pinPoint?.id {
                self?.showCollaborationWindow(forGeometry: geometryId)
            } else {
                self?.collaborationFlow.hideCollaborationWindow(animated: true)
            }
        }
    }

    private func showCollaborationWindow(forGeometry geometryId: String) {
        // minimize the action card when showing collab
        actionCardVC.cardDragging?.setPosition(.min, withVelocity: 0, animated: true)
        // hide media/fullscreen
        if let fullscreenMediaVC = fullscreenMediaVC {
            fullscreenMediaVC.dismissCard()
        }
        if let mediaVC = mediaVC {
            mediaVC.dismissCard()
        }
        if let taskListVC = taskListVC {
            taskListVC.dismissCard()
        }
        collaborationFlow.showCollaborationWindow(forGeometry: geometryId, animated: true)
    }

    func stop() {
        collaborationFlow.stop()
        pinsDisplay?.stop()
        if let canvasDelegateId = canvasDelegateId {
            canvasContainer.canvasViewController.removeDelegate(id: canvasDelegateId)
        }
        canvasContainer.removeCard(cardViewController: actionCardVC)
        // dismiss any presented modally VCs
        canvasContainer.dismiss(animated: false)
        remove(childController: canvasContainer)
        debugSettingsNativeViewsForPinsSubscriber?.cancel()
        debugSettingsNativeViewsForPinsSubscriber = nil
        currentCanvasObservation?.invalidate()
        currentCanvasObservation = nil
        canvasNotificationToken?.invalidate()
        canvasNotificationToken = nil
        geometriesNotificationToken?.invalidate()
        geometriesNotificationToken = nil
        UserDefaults.setCanvasFilters(canvasFilters, forProjectId: model.projectId)
        NotificationCenter.default.removeObserver(self)
    }

    /// Show the default UI elements when viewing the canvas
    func showDefaultCanvasUI(animated: Bool = true) {
        defaultCanvasUIHidden = false
        actionCardVC.showCard(animated: animated)
        controls.canvasSelectorButton?.isHidden = false
        controls.canvasSourceSelectorButton?.isHidden = canvasSourceSelectorHidden
        controls.canvasFiltersButton?.isHidden = false
        pinsDisplay?.start(onInitialLoad: nil)
    }

    /// Hide the default UI elements when viewing the canvas
    func hideDefaultCanvasUI(animated: Bool = true) {
        defaultCanvasUIHidden = true
        actionCardVC.hideCard(animated: animated)
        controls.canvasSelectorButton?.isHidden = true
        controls.canvasSourceSelectorButton?.isHidden = true
        controls.canvasFiltersButton?.isHidden = true
        pinsDisplay?.stop()
    }

    // Update for current canvas. Hide if not a pdf.
    fileprivate func updateTopIndicatorView() {
        if model.currentCanvas.currentCanvasSource.type == .pdf {
            controls.showTopIndicatorView(text: model.currentCanvas.displayName, animated: true)
        } else {
            controls.hideTopIndicatorView(animated: true)
        }
    }

    var canvasSourceSelectorHidden: Bool { model.currentCanvas.canvasSources.count <= 1 }

    fileprivate func updateCanvasSourceSelectorVisibility() {
        guard let canvasSourceSelectorButton = controls.canvasSourceSelectorButton else { return }
        canvasSourceSelectorButton.isHidden = canvasSourceSelectorHidden || defaultCanvasUIHidden

        guard let canvasFiltersButton = controls.canvasFiltersButton else { return }
        canvasFiltersButton.snp.remakeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            if canvasSourceSelectorHidden, let canvasSelectorButton = controls.canvasSelectorButton {
                make.bottom.equalTo(canvasSelectorButton.snp.top).offset(-12)
            } else {
                make.bottom.equalTo(canvasSourceSelectorButton.snp.top).offset(-12)
            }
        }
    }

    /// Shows view controller for debug settings
    @objc func showDebugSettingsAction() {
        let debugSettingsVC = UIHostingController(
            rootView: DebugSettingsView().environmentObject(debugSettings)
        )
        present(debugSettingsVC, animated: true)
    }

    @objc func showTypeScaleAction() {
        TypeScaleCardViewController().installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    fileprivate func setupActionCardVC() -> ProjectActionCardViewController {
        let showDebugOptions: Bool = try! AppConfiguration.bool(for: "ShowDebugOptions")
        let additionalCardActions = showDebugOptions
            ? [
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
                ActionItem(
                    title: "Type Scale",
                    imageName: "textformat.size",
                    handler: { [weak self] in
                        self?.showTypeScaleAction()
                    }
                ),
            ]
            : []
        let vc = ProjectActionCardViewController(actions: additionalCardActions)
        vc.onCamera = { [weak self] in
            self?.startAddPhotoFlow()
        }
        vc.onAddPin = { [weak self] in
            self?.startAddPinFlow()
        }

        canvasContainer.installCard(cardViewController: vc,
                                    inView: canvasContainer.controls,
                                    cardConfig: CardConfiguration(
                                        linkedViewToLayout: canvasContainer.controls,
                                        showSafeAreaBlur: true
                                    ))
        return vc
    }
}

// MARK: - canvas delegate

extension ProjectFlowController: CanvasViewControllerDelegate {
    func canvasCameraChanged(reason: CanvasCameraChangeReason) {
        if reason == .pan || reason == .zoom {
            // cancel any delayed fade in if user restarted interaction between the throttle timeout
            canvasIndicatorViewFadeDelayer.cancel()
            controls.fadeOutTopIndicatorView()
        } else if reason == .panEnd || reason == .zoomEnd {
            canvasIndicatorViewFadeDelayer.delay { [weak self] in
                self?.controls.fadeInTopIndicatorView()
            }
        }
        if reason == .panEnd || reason == .zoomEnd || reason == .programmatic {
            reportPresenceThrottler.throttle { [weak self] in
                self?.reportPresence()
            }
        }
    }

    func canvasTapRecognized(at _: CGPoint) {}
}

// MARK: - canvas filters {

extension ProjectFlowController {
    /// Updates the filters indicator badge visibility and number to indicate that filters are affecting the visible pins.
    /// There is special treatment applied to archived pins - we don't want to show the indicator that archived pins are hidden when the
    /// filters has them disabled (because we want to hide the archived pins by default)
    /// Called when filters change or pins are updated or canvas is switched.
    @objc private func updateFiltersIndicatorBadge() {
        let allPins = model.currentCanvas.pins
            .compactMap(\.features.first?.collaborations.first) // geometry => collaboration

        // filters hide the archived pins by default and we don't want to show the indicator if the
        // only affected pins are the archived ones
        let allNonArchivedPins = allPins.filter { !$0.isArchived }

        let filteredPinsCount = allPins.filter(canvasFilters.match).count

        if canvasFilters.showArchivedPins {
            // don't show the indicator if filter is not impacting the visible pins
            controls.canvasFiltersIndicatorBadge?.isHidden = filteredPinsCount == allPins.count
        } else {
            // don't show the indicator if filter is not impacting the visible non archived pins
            controls.canvasFiltersIndicatorBadge?.isHidden = filteredPinsCount == allNonArchivedPins.count
        }

        // show the pins count (including the archived pins if enabled)
        controls.canvasFiltersIndicatorBadge?.text = filteredPinsCount >= 99 ? "99+" : String(filteredPinsCount)
    }
}

// MARK: - actions

extension ProjectFlowController {
    /// Reports the current canvas and position so it can be displayed on other devices
    private func reportPresence() {
        let coordinates = canvasContainer.annotationsMapView.cameraState.center
        modelFirestoreSync.reportPresence(coordinates: coordinates)
    }

    private func startAddPhotoFlow() {
        addPhotoFlow = AddPhotoFlowController(
            model: model,
            localFiles: localFiles,
            mediaCache: mediaCache,
            canvasContainer: canvasContainer
        )
        addPhotoFlow?.onStop = { [weak self] geometryId, newlyCreated, shouldEdit in
            self?.showDefaultCanvasUI()
            self?.addPhotoFlow = nil
            if let geometryId = geometryId, newlyCreated ?? false == true {
                self?.selectCollaboration(forGeometryId: geometryId, andEditName: shouldEdit ?? false)
            }
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

    private func startAddPinFlow() {
        // minimize the action card
        actionCardVC.cardDragging?.setPosition(.min, withVelocity: 0, animated: true)

        addPinFlow = AddPinFlowController(model: model, canvasContainer: canvasContainer)
        addPinFlow?.onStop = { [weak self] geometryId, pinTypeOption in
            guard let self = self else { return }
            self.showDefaultCanvasUI()
            if let geometryId = geometryId {
                // don't edit name if it was .taskCopy
                self.selectCollaboration(forGeometryId: geometryId, andEditName: pinTypeOption != .copyTask)
            }
            self.addPinFlow = nil
        }
        hideDefaultCanvasUI()
        addPinFlow?.start()
    }

    private func selectCollaboration(forGeometryId geometryId: String, andEditName editName: Bool) {
        reloadGeometriesPinsDisplay(useNativeViews: debugSettings.nativeViewsForPins) {
            if let pinsDisplay = self.pinsDisplay, let pin = pinsDisplay.pinForGeometryId(geometryId) {
                // select the pin (which will trigger showing the collaboration window)
                pinsDisplay.setSelectedPin(pin)
                if editName {
                    DispatchQueue.main.async {
                        self.collaborationFlow.editNameAction()
                    }
                }
            }
        }
    }
}
