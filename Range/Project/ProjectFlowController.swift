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
    /// The state represents a UI configuration in which the canvas is visible but has a different set of additional views.
    enum UIState {
        case `default` // showing the project controls
        case collaboration // when the collaboration view is open (or any view open from it)
        case addPhoto // photo flow is started
        case addPin // add pin flow is started
        case movePin // move pin flow is started
        case fullScreenCanvas // the projects controls are hidden, showing the canvas in full screen (still showing the pins)
    }

    // the initial state is set in `start` method
    private var uiState: UIState?

    unowned let localFiles: LocalFiles
    unowned let mediaCache: MediaCache
    unowned let canvasFileLoader: CanvasFileLoader
    let model: ProjectModel
    let modelFirestoreSync: ProjectModelFirestoreSync

    let canvasContainer: CanvasContainerViewController
    let collaborationFlow: CollaborationFlowController

    let userSettings: UserSettings
    /// for storing the debugSettings observer(s)
    private var debugSettingsNativeViewsForPinsSubscriber: AnyCancellable?

    lazy var actionCardVC = setupActionCardVC()
    var actionCardDraggingDelegateId: UUID?
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
    /// Token for observing canvas sources to (re)download their pdfs
    private var canvasSourcesNotificationToken: NotificationToken?

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

    // Canvas filters for this project
    let canvasFilters: CanvasFilters
    // Default filters, never updated, for comparison of current filters output vs the default one for filters indicator badge
    let defaultCanvasFilters: CanvasFilters

    /// Arbitrary way of deciding whether user is currently editing the project (so in the middle of some meaningful action that should not
    /// be aborted without confirmation)
    var isUserEditingProject: Bool {
        // some flow is running:
        uiState == .addPhoto || uiState == .addPin || uiState == .movePin
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
        canvasFileLoader: CanvasFileLoader,
        pendingUploadsModel: PendingUploadsModel,
        pendingActionsModel: PendingActionsModel,
        userSettings: UserSettings
    ) async throws {
        self.localFiles = localFiles
        self.mediaCache = mediaCache
        self.canvasFileLoader = canvasFileLoader
        model = try ProjectModel(
            userId: userId,
            projectId: projectId,
            localFiles: localFiles,
            mediaCache: mediaCache,
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
        defaultCanvasFilters = CanvasFilters()
        defaultCanvasFilters.model = model

        canvasContainer = try await CanvasContainerViewController(
            model: model,
            canvasFilters: canvasFilters,
            canvasFileLoader: canvasFileLoader
        )
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
        createGeometriesPinsDisplay(useNativeViews: _debugSettings.nativeViewsForPins)
        add(childController: canvasContainer)
        canvasContainer.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        canvasContainer.view.setNeedsLayout()
        canvasContainer.view.layoutIfNeeded()

        if !UserDefaults.cardOnboardingComplete {
            controls.showCardOnboardingView(aboveView: actionCardVC.view)
            actionCardDraggingDelegateId = actionCardVC.cardDragging?.addDelegate(self)
        }

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

        setUIState(.default, animated: false)

        updateCanvasSourceSelectorVisibility()
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
                useNativeViews: _debugSettings.nativeViewsForPins,
                onReloaded: nil
            )
            self.updateFiltersIndicatorBadge()
        }

        canvasDelegateId = canvasContainer.canvasViewController.addDelegate(self)

        startedFuturePromise?(.success(()))

        // after the project is started, and on each canvas source change, download all the pdfs for all pdf canvas sources
        canvasSourcesNotificationToken = model.mainRealm.objects(CanvasSource.self).observe { [weak self] _ in
            self?.possiblyDownloadPdfsForCanvasSources()
        }
    }

    /// Iterates over all pdf canvas sources and triggers the pdf file download.
    /// If the file is available locally it will not be redownloaded
    @MainActor
    private func possiblyDownloadPdfsForCanvasSources() {
        let pdfSources = model.mainRealm.objects(CanvasSource.self).filter { $0.data.type == .pdf }
        for pdfSource in pdfSources {
            canvasFileLoader.downloadPDF(forSource: pdfSource, projectId: model.projectId)
        }
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
        debugSettingsNativeViewsForPinsSubscriber = _debugSettings.$nativeViewsForPins
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
                self?.setUIState(.collaboration, animated: true)
                self?.collaborationFlow.showCollaborationWindow(forGeometry: geometryId, animated: true)
            } else {
                self?.setUIState(.default, animated: true)
                self?.collaborationFlow.hideCollaborationWindow(animated: true)
            }
        }
        pinsDisplay?.onCanvasTap = { [weak self] in
            guard let self = self else { return }
            // Toggle fullscreen on canvas tap (but only in the default state)
            if self.uiState == .default {
                self.setUIState(.fullScreenCanvas, animated: true)
            } else if self.uiState == .fullScreenCanvas {
                self.setUIState(.default, animated: true)
            }
        }
    }

    func stop() {
        collaborationFlow.stop()
        pinsDisplay?.stop()
        if let canvasDelegateId = canvasDelegateId {
            canvasContainer.canvasViewController.removeDelegate(id: canvasDelegateId)
        }
        actionCardVC.cardDragging?.removeDelegate(actionCardDraggingDelegateId)
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
        canvasSourcesNotificationToken?.invalidate()
        canvasSourcesNotificationToken = nil
        UserDefaults.setCanvasFilters(canvasFilters, forProjectId: model.projectId)
        NotificationCenter.default.removeObserver(self)
    }

    /// Show/hide the controls depending on the state
    func setUIState(_ state: UIState, animated: Bool) {
        uiState = state

        if state == .fullScreenCanvas {
            controls.hideTopViewController(animated: true)
        } else {
            controls.showTopViewController(title: model.projectSummary.name, onBack: onBack, animated: false)
        }
        updateTopIndicatorView()

        if state == .default {
            actionCardVC.showCard(animated: animated)
            controls.canvasSelectorButton?.isHidden = false
            controls.canvasSourceSelectorButton?.isHidden = canvasSourceSelectorHidden
            controls.canvasFiltersButton?.isHidden = false
            pinsDisplay?.start(onInitialLoad: nil)
        } else if state == .collaboration {
            // we don't hide the controls, only hide additional cards and minimize the action card
            actionCardVC.cardDragging?.setPosition(.min, withVelocity: 0, animated: true)
            fullscreenMediaVC?.dismissCard()
            mediaVC?.dismissCard()
            taskListVC?.dismissCard()
        } else if state == .fullScreenCanvas {
            actionCardVC.hideCard(animated: animated)
            controls.canvasSelectorButton?.isHidden = true
            controls.canvasSourceSelectorButton?.isHidden = true
            controls.canvasFiltersButton?.isHidden = true
        } else {
            actionCardVC.hideCard(animated: animated)
            controls.canvasSelectorButton?.isHidden = true
            controls.canvasSourceSelectorButton?.isHidden = true
            controls.canvasFiltersButton?.isHidden = true
            pinsDisplay?.stop()
        }
    }

    // Update for current canvas. Hide if not a pdf.
    fileprivate func updateTopIndicatorView() {
        if model.currentCanvas.currentCanvasSource.type == .pdf, uiState != .fullScreenCanvas {
            controls.showTopIndicatorView(text: model.currentCanvas.displayName, animated: true)
        } else {
            controls.hideTopIndicatorView(animated: true)
        }
    }

    var canvasSourceSelectorHidden: Bool { model.currentCanvas.canvasSources.count <= 1 }

    fileprivate func updateCanvasSourceSelectorVisibility() {
        guard let canvasSourceSelectorButton = controls.canvasSourceSelectorButton else { return }
        canvasSourceSelectorButton.isHidden = canvasSourceSelectorHidden
            // canvas source selector used in other flows is added by these flows if needed
            || !(uiState == .default || uiState == .collaboration)

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
            rootView: DebugSettingsView().environmentObject(_debugSettings)
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

// MARK: - action card dragging delegate

extension ProjectFlowController: CardDraggingDelegate {
    func cardDidChangePosition(_ position: CardPosition) {
        if position == .max {
            // mark the card onboarding complete
            UserDefaults.cardOnboardingComplete = true

            // and hide the onboarding animation with 1s delay
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) { [weak self] in
                self?.controls.hideCardOnboardingView()
            }
        }
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
    /// Called when filters change or pins are updated or canvas is switched.
    @objc private func updateFiltersIndicatorBadge() {
        let allPins = model.currentCanvas.pins
            .compactMap(\.features.first?.collaborations.first) // geometry => collaboration

        let filteredPinsCount = allPins.filter(canvasFilters.match).count
        let defaultFilteredPinsCount = allPins.filter(defaultCanvasFilters.match).count

        // don't show the indicator if filter is not impacting the visible pins
        controls.canvasFiltersIndicatorBadge?.isHidden = filteredPinsCount == defaultFilteredPinsCount

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
            self?.setUIState(.default, animated: true)
            self?.addPhotoFlow = nil
            if let geometryId = geometryId, newlyCreated ?? false == true {
                self?.selectCollaboration(forGeometryId: geometryId, andEditName: shouldEdit ?? false)
            }
        }
        addPhotoFlow?.start { [weak self] started in
            // hide cards if photo flow started
            if started {
                self?.setUIState(.addPhoto, animated: true)
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
            self.setUIState(.default, animated: true)
            if let geometryId = geometryId {
                // don't edit name if it was .taskCopy
                self.selectCollaboration(forGeometryId: geometryId, andEditName: pinTypeOption != .copyTask)
            }
            self.addPinFlow = nil
        }
        setUIState(.addPin, animated: true)
        addPinFlow?.start()
    }

    private func selectCollaboration(forGeometryId geometryId: String, andEditName editName: Bool) {
        reloadGeometriesPinsDisplay(useNativeViews: _debugSettings.nativeViewsForPins) {
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
