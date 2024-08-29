import Combine
import Kingfisher
import Lottie
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
        case locationSimulation // taps are interpreted as setting new simulated user (blue dot) location
        case canvasSnapshot // the flow to take canvas snapshot is started
    }

    /// In each app session we want to expand the action card initially so the user knows it can be expanded.
    /// It the automatically closes (as it usually does when user is interacting with the map)
    static var actionCardInitiallyExpanded = true

    // the initial state is set in `start` method
    private(set) var uiState: UIState?

    let localFiles: LocalFiles
    let mediaCache: MediaCache
    let canvasFileLoader: CanvasFileLoader
    let userModel: UserModel
    let model: ProjectModel
    let modelFirestoreSync: ProjectModelFirestoreSync
    let userDataSyncState: UserDataSyncState

    /// Project level in app feed
    let knockFeedModel: KnockFeedModel

    let canvasContainer: CanvasContainerViewController
    let collaborationFlow: CollaborationFlowController

    let userSettings: UserSettings
    /// for storing the debugSettings observer(s)
    private var debugSettingsNativeViewsForPinsSubscriber: AnyCancellable?
    let userPreferences: UserPreferences

    lazy var actionCardVC = setupActionCardVC()
    var actionCardDraggingDelegateId: UUID?
    var pinsDisplay: GeometriesPinsDisplay?
    let controls: ProjectCanvasControls
    weak var mediaVC: MediaCardViewController?
    weak var fullscreenMediaVC: FullscreenMediaCardViewController?
    weak var taskListVC: TaskListCardViewController?

    /// To observed changes in model.currentCanvas
    private var currentCanvasObservation: NSKeyValueObservation?
    /// Observe canvas source to update UI based on the canvas source type
    private var currentCanvasSourceObservation: NSKeyValueObservation?
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
    var canvasSnapshotFlow: CanvasSnapshotFlowController?

    var started = false
    var onBack: (() -> Void)?

    // Canvas pin filters for this project
    let canvasFilters: CollaborationFilters
    // Default filters, never updated, for comparison of current filters output vs the default one for filters indicator badge
    let defaultCanvasFilters: CollaborationFilters

    let checkmarkAnimationView = LottieAnimationView(asset: "checkmark_animation")

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

    /// Location provider for tracking user on map canvases
    private let locationProvider = RangeLocationProvider()

    private let initialRoute: ProjectRoute?

    /// combine observers
    private var subscriptions = Set<AnyCancellable>()

    /// Initialize ProjectFlowController
    /// This can throw if project model cannot be loaded or started
    ///
    /// - Parameters:
    ///     - userId: range id of the logged in user
    ///     - projectId: id of the project
    ///     - canvasId: id of the canvas, if not provided then load the 1st canvas in a project
    init(
        userModel: UserModel,
        projectId: String,
        canvasId: String?,
        localFiles: LocalFiles,
        mediaCache: MediaCache,
        canvasFileLoader: CanvasFileLoader,
        pendingUploadsModel: PendingUploadsModel,
        pendingActionsModel: PendingActionsModel,
        userDataSyncState: UserDataSyncState,
        userSettings: UserSettings,
        userPreferences: UserPreferences,
        initialRoute: ProjectRoute?
    ) async throws {
        self.localFiles = localFiles
        self.mediaCache = mediaCache
        self.canvasFileLoader = canvasFileLoader
        self.initialRoute = initialRoute
        self.userModel = userModel
        model = try ProjectModel(
            userId: userModel.userId,
            projectId: projectId,
            localFiles: localFiles,
            mediaCache: mediaCache,
            userPreferences: userPreferences,
            pendingUploadsModel: pendingUploadsModel,
            pendingActionsModel: pendingActionsModel
        )
        self.userDataSyncState = userDataSyncState
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
        self.userPreferences = userPreferences
        canvasFilters = userPreferences.canvasFilters(forModel: model)
        canvasFilters.model = model
        defaultCanvasFilters = CollaborationFilters(model: model, variant: .canvas)
        defaultCanvasFilters.model = model

        canvasContainer = try await CanvasContainerViewController(
            model: model,
            canvasFilters: canvasFilters,
            canvasFileLoader: canvasFileLoader,
            locationProvider: locationProvider
        )
        collaborationFlow = CollaborationFlowController(
            model: model,
            localFiles: localFiles,
            mediaCache: mediaCache,
            userSettings: userSettings,
            userPreferences: userPreferences,
            canvasContainer: canvasContainer
        )
        self.userSettings = userSettings
        controls = ProjectCanvasControls(canvasContainer: canvasContainer)

        knockFeedModel = KnockFeedModel(knockClient: userModel.knockClient, projectId: projectId)

        super.init(nibName: nil, bundle: nil)

        // Make this view controller part of the responder chain for view controllers presented modally
        // on top of it. If not set the responder chain for VCs presented modally would skip it and
        // go to the root view controller of the window. We need it to pass events from photo flow
        // controller (which unlike the rest of the vcs presents the content modally)
        definesPresentationContext = true

        collaborationFlow.onCollaborationClose = { [weak self] in
            // unselect pin, this will result also in hiding the collaboration window
            self?.pinsDisplay?.setSelectedPin(nil)
        }

        knockFeedModel.$feed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.controls.updateInAppUnseenItemsBadge(self.knockFeedModel)
            }
            .store(in: &subscriptions)
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        controls.followMeModeButton?.isHidden = !followMeModeButtonVisible
        controls.locationSimulationButton?.isHidden = !locationSimulationButtonVisible
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

        // only show the card onboarding if user can create a collaboration, so is not a Guest
        // If user is a Guest then currently the card has a fixed size
        if !userPreferences.cardOnboardingComplete, model.currentUser.canCreateCollaboration() {
            controls.showCardOnboardingView(aboveView: actionCardVC.view)
            actionCardDraggingDelegateId = actionCardVC.cardDragging?.addDelegate(self)
        }

        controls.showFollowMeModeButton(aboveView: actionCardVC.view)
        if AppConfiguration.showDebugOptions {
            controls.showLocationSimulationButton(aboveView: controls.followMeModeButton!)
        }

        controls.showCanvasSelectorButton(aboveView: actionCardVC.view)
        controls.showCanvasSourceSelectorButton(aboveView: controls.canvasSelectorButton!)
        controls.showCanvasFiltersButton(aboveView: controls.canvasSourceSelectorButton!)
        controls.showCanvasFiltersIndicatorBadge()
        updateFiltersIndicatorBadge()
        // observe the filters and update the filters indicator badge on change
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateFiltersIndicatorBadge),
            name: canvasFilters.updateNotificationName, object: nil
        )

        setUIState(.default, animated: false)

        updateCanvasSourceSelectorVisibility()
        controls.followMeModeButton?.isHidden = !followMeModeButtonVisible
        controls.locationSimulationButton?.isHidden = !locationSimulationButtonVisible
        collaborationFlow.start()
        observeDebugSettings()
        observeCanvas()

        currentCanvasObservation = model.observe(\.currentCanvas) { [weak self] _, _ in
            guard let self = self else { return }
            guard !self.model.currentCanvas.isInvalidated else { return }
            self.observeCurrentCanvasSource()
            self.controls.followMeModeButton?.isHidden = !followMeModeButtonVisible
            self.controls.locationSimulationButton?.isHidden = !locationSimulationButtonVisible
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
        observeCurrentCanvasSource()

        canvasDelegateId = canvasContainer.canvasViewController.addDelegate(self)

        // after the project is started, and on each canvas source change, download all the pdfs for all pdf canvas sources
        canvasSourcesNotificationToken = model.mainRealm.objects(CanvasSource.self).observe { [weak self] _ in
            self?.possiblyDownloadPdfsForCanvasSources()
        }

        analytics?.screen(title: "project canvas", properties: [
            "projectType": model.projectSummary.projectType,
        ])

        canvasContainer.annotationsMapView.viewport.addStatusObserver(self)
        // visibility of location related controls depends on the location authorization
        locationProvider.onAuthorizationUpdate = { [weak self] in
            guard let self = self else { return }
            self.controls.followMeModeButton?.isHidden = !self.followMeModeButtonVisible
            self.controls.locationSimulationButton?.isHidden = !self.locationSimulationButtonVisible
        }
        // visibility of location related controls depends on the user proximity to canvas center
        locationProvider.addLocationObserver(for: self)

        knockFeedModel.start()

        if let initialRoute {
            showRoute(initialRoute)
        }
    }

    /// Adjust the project flow controller state for given ProjectRoute
    func showRoute(_ route: ProjectRoute) {
        setUIState(.default, animated: true)
        switch route.route {
        case let .canvas(_: canvasId):
            if model.currentCanvas.id != canvasId,
               let canvas = model.sortedCanvases.first(where: { $0.id == canvasId })
            {
                // show canvas
                do {
                    try model.setCurrentCanvas(canvas)
                } catch {
                    ToastWindow.shared.showError(text: "Canvas failed to load")
                }
            }

        case .welcome: showHowToAddPDFFloorPlansCard()
        case .tasks: showTaskListAction()
        case let .collaboration(_: collaborationId):
            // show given collaboration, it'll switch the canvas if needed
            if let collaboration = model.mainRealm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) {
                showCollaborationAction(sender: self, event: FlowEvent(collaboration))
            }
        case .media: showMediaAction()
        case let .fullscreenMedia(_: uploadId):
            showMediaAction()
            if let upload = model.mainRealm.object(ofType: Upload.self, forPrimaryKey: uploadId) {
                showFullscreenMediaAction(sender: self, event: FlowEvent(upload, source: .media))
            }
        }
    }

    /// Observe when canvas source is switched to different canvas source
    private func observeCurrentCanvasSource() {
        currentCanvasSourceObservation?.invalidate()
        currentCanvasSourceObservation = model.currentCanvas
            .observe(\.currentCanvasSource, options: [.old]) { [weak self] _, _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.controls.followMeModeButton?.isHidden = !self.followMeModeButtonVisible
                    self.controls.locationSimulationButton?.isHidden = !self.locationSimulationButtonVisible
                }
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
        canvasContainer.annotationsMapView.viewport.removeStatusObserver(self)
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
        userPreferences.setCanvasFilters(canvasFilters, forProjectId: model.projectId)
        NotificationCenter.default.removeObserver(self)
        knockFeedModel.stop()
    }

    /// Show/hide the controls depending on the state
    func setUIState(_ state: UIState, animated: Bool) {
        uiState = state

        if state == .default || state == .collaboration || state == .locationSimulation {
            controls.showTopViewController(
                title: model.projectSummary.name,
                onBack: onBack,
                showInAppFeedButton: true,
                userDataSyncState: userDataSyncState,
                animated: animated
            )
        } else {
            controls.hideTopViewController(animated: animated)
        }
        updateTopIndicatorView()

        if state != .locationSimulation {
            // toggle off locationSimulationButton on ui state change
            controls.locationSimulationButton?.isSelected = false
        }

        if state == .default {
            if ProjectFlowController.actionCardInitiallyExpanded, userPreferences.cardOnboardingComplete {
                // when showing the project flow controller initially we want the card maximized
                // But not if user hasn't completed the card onboarding
                actionCardVC.cardDragging?.setPosition(.max, withVelocity: 0)
                ProjectFlowController.actionCardInitiallyExpanded = false
            } else {
                // if coming back from other states we want the card minimized (as it should
                // minimize on any user interaction)
                actionCardVC.cardDragging?.setPosition(.min, withVelocity: 0, animated: animated)
            }
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
        } else if state == .locationSimulation {
            // location simulation hides the pins so user can tap anywhere in the canvas to simulate user position
            actionCardVC.hideCard(animated: animated)
            controls.canvasSelectorButton?.isHidden = true
            controls.canvasSourceSelectorButton?.isHidden = true
            controls.canvasFiltersButton?.isHidden = true
            pinsDisplay?.stop()
        } else {
            actionCardVC.hideCard(animated: animated)
            controls.canvasSelectorButton?.isHidden = true
            controls.canvasSourceSelectorButton?.isHidden = true
            controls.canvasFiltersButton?.isHidden = true
            pinsDisplay?.stop()
        }
        controls.followMeModeButton?.isHidden = !followMeModeButtonVisible
        controls.locationSimulationButton?.isHidden = !locationSimulationButtonVisible
    }

    // Update for current canvas.
    fileprivate func updateTopIndicatorView() {
        if uiState != .fullScreenCanvas {
            controls.showTopIndicatorView(text: model.currentCanvas.name, animated: true)
        } else {
            controls.hideTopIndicatorView(animated: true)
        }
    }

    var followMeModeButtonVisible: Bool {
        guard uiState == .default || uiState == .locationSimulation else { return false }
        guard model.currentCanvas.currentCanvasSource.type != .pdf else { return false }
        guard locationProvider.authorizationStatus == .authorizedAlways || locationProvider
            .authorizationStatus == .authorizedWhenInUse else { return false }
        guard let userLocation = canvasContainer.annotationsMapView.location.latestLocation else { return false }
        guard model.isLocationInCurrentCanvasSourceRange(userLocation.coordinate) else { return false }
        return true
    }

    var locationSimulationButtonVisible: Bool {
        guard AppConfiguration.showDebugOptions else { return false }
        guard uiState == .default || uiState == .locationSimulation else { return false }
        guard model.currentCanvas.currentCanvasSource.type != .pdf else { return false }
        guard locationProvider.authorizationStatus == .authorizedAlways || locationProvider
            .authorizationStatus == .authorizedWhenInUse else { return false }
        return true
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

    fileprivate func setupActionCardVC() -> ProjectActionCardViewController {
        let vc = ProjectActionCardViewController(model: model)
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
            userPreferences.cardOnboardingComplete = true

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

        // minimize the bottom card on any interaction
        if let cardDragging = actionCardVC.cardDragging, !cardDragging.isCardHidden, cardDragging.position == .max {
            cardDragging.setPosition(.min, withVelocity: 0, animated: true)
        }
    }

    func canvasTapRecognized(at point: CGPoint) {
        guard uiState == .locationSimulation else { return }
        let mapLocation = canvasContainer.annotationsMapView.mapboxMap.coordinate(for: point)
        locationProvider.setSimulatedLocation(mapLocation)
    }

    func canvasLongPressRecognized(at _: CGPoint) {}
}

// MARK: - canvas filters {

extension ProjectFlowController {
    /// Updates the filters indicator badge visibility and number to indicate that filters are affecting the visible pins.
    /// Called when filters change or pins are updated or canvas is switched.
    @objc private func updateFiltersIndicatorBadge() {
        let threadSafeCanvas = ThreadSafeReference(to: model.currentCanvas)
        // switch to background realm and queue to calculate the filters results outside of the main UI queue
        // This function is called frequently on project initial load (because pins are being loaded)
        // and it was freezing the UI when filtering was done on the main thread.
        model.writeQueue.async { [weak self] in
            guard let self, let canvas = self.model.writeRealm.resolve(threadSafeCanvas) else { return }
            let allPins = canvas.pins.compactMap(\.collaborations.first) // geometry => collaboration

            let filteredPinsCount = allPins.filter(self.canvasFilters.match).count
            let defaultFilteredPinsCount = allPins.filter(self.defaultCanvasFilters.match).count

            DispatchQueue.main.async {
                // don't show the indicator if filter is not impacting the visible pins
                self.controls.canvasFiltersIndicatorBadge?.isHidden = filteredPinsCount == defaultFilteredPinsCount

                // show the pins count (including the archived pins if enabled)
                self.controls.canvasFiltersIndicatorBadge?
                    .text = filteredPinsCount >= 99 ? "99+" : String(filteredPinsCount)
            }
        }
    }
}

// MARK: - actions

extension ProjectFlowController {
    /// Reports the current canvas and position so it can be displayed on other devices
    private func reportPresence() {
        let coordinates = canvasContainer.annotationsMapView.mapboxMap.cameraState.center
        modelFirestoreSync.reportPresence(coordinates: coordinates)
    }

    private func startAddPhotoFlow() {
        addPhotoFlow = AddPhotoFlowController(
            model: model,
            localFiles: localFiles,
            mediaCache: mediaCache,
            userSettings: userSettings,
            userPreferences: userPreferences,
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
        addPinFlow = AddPinFlowController(
            model: model,
            userPreferences: userPreferences,
            canvasContainer: canvasContainer
        )
        addPinFlow?.onStop = { [weak self] geometryId, pinTypeOption in
            guard let self = self else { return }
            self.setUIState(.default, animated: true)
            if let geometryId = geometryId {
                // don't edit name if it was .taskCopy
                self.selectCollaboration(forGeometryId: geometryId, andEditName: pinTypeOption != .copyPin)
            }
            self.addPinFlow = nil
        }
        setUIState(.addPin, animated: true)
        addPinFlow?.start()
    }

    func selectCollaboration(forGeometryId geometryId: String, andEditName editName: Bool) {
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
