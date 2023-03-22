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
    /// for storing the userSettings observer
    private var userSettingsShowArchivedPinsSubscriber: AnyCancellable?
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

    /// id of registered canvas delegate
    var canvasDelegateId: UUID?

    /// throttle the presence reporting when canvas camera changes, report no more frequently than every 0.5 seconds
    var reportPresenceThrottler = Throttler(throttleTime: 0.5)

    var addPhotoFlow: AddPhotoFlowController?
    var addPinFlow: AddPinFlowController?
    var movePinFlow: MovePinFlowController?

    var started = false
    var onBack: (() -> Void)?

    private var defaultCanvasUIHidden = false

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

        canvasContainer = try await CanvasContainerViewController(model: model)
        collaborationFlow = CollaborationFlowController(
            model: model,
            localFiles: localFiles,
            mediaCache: mediaCache,
            canvasContainer: canvasContainer
        )
        self.userSettings = userSettings
        controls = ProjectCanvasControls(canvasContainer: canvasContainer)

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
        createGeometriesPinsDisplay(
            useNativeViews: debugSettings.nativeViewsForPins,
            showArchivedCollaborations: userSettings.showArchivedCollaborations
        )
        add(childController: canvasContainer)
        canvasContainer.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        canvasContainer.view.setNeedsLayout()
        canvasContainer.view.layoutIfNeeded()

        controls.showTopViewController(title: model.projectSummary.name, onBack: onBack, animated: false)

        controls.showCanvasSelectorButton(aboveView: actionCardVC.view)
        controls.showCanvasSourceSelectorButton(aboveView: controls.canvasSelectorButton!)
        controls.showCanvasFiltersButton(aboveView: controls.canvasSourceSelectorButton!)
        updateCanvasSourceSelectorVisibility()

        showDefaultCanvasUI(animated: false)
        collaborationFlow.start()
        observeUserSettings()
        observeDebugSettings()
        observeCanvas()

        currentCanvasObservation = model.observe(\.currentCanvas) { [weak self] _, _ in
            guard let self = self else { return }
            guard !self.model.currentCanvas.isInvalidated else { return }
            self.updateCanvasSourceSelectorVisibility()
            // observe if the current canvas is removed
            self.observeCanvas()
            self.reloadGeometriesPinsDisplay(
                useNativeViews: self.debugSettings.nativeViewsForPins,
                showArchivedCollaborations: self.userSettings.showArchivedCollaborations,
                onReloaded: nil
            )
        }

        canvasDelegateId = canvasContainer.canvasViewController.addDelegate(self)
    }

    private func observeCanvas() {
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
    func reloadGeometriesPinsDisplay(
        useNativeViews: Bool,
        showArchivedCollaborations: Bool,
        onReloaded: (() -> Void)?
    ) {
        let start = pinsDisplay?.started ?? false
        pinsDisplay?.stop()
        createGeometriesPinsDisplay(
            useNativeViews: useNativeViews,
            showArchivedCollaborations: showArchivedCollaborations
        )
        if start {
            pinsDisplay?.start(onInitialLoad: onReloaded)
        }
    }

    private func observeDebugSettings() {
        debugSettingsNativeViewsForPinsSubscriber = debugSettings.$nativeViewsForPins
            .sink { [weak self] useNativeViews in
                guard let self = self else { return }
                self.reloadGeometriesPinsDisplay(
                    useNativeViews: useNativeViews,
                    showArchivedCollaborations: self.userSettings.showArchivedCollaborations,
                    onReloaded: nil
                )
            }
    }

    /// Observe user settings to detect change in showArchivedCollaborations
    private func observeUserSettings() {
        userSettingsShowArchivedPinsSubscriber = userSettings.$showArchivedCollaborations
            .sink { [weak self] showArchivedCollaborations in
                guard let self = self else { return }
                self.reloadGeometriesPinsDisplay(
                    useNativeViews: self.debugSettings.nativeViewsForPins,
                    showArchivedCollaborations: showArchivedCollaborations,
                    onReloaded: nil
                )
            }
    }

    private func createGeometriesPinsDisplay(useNativeViews: Bool, showArchivedCollaborations: Bool) {
        pinsDisplay = _createGeometriesPinsDisplay(
            usingNativeViews: useNativeViews,
            canvas: model.currentCanvas,
            canvasViewController: canvasContainer.canvasViewController,
            deselectOnCanvasTap: true,
            showArchivedPins: showArchivedCollaborations,
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
        remove(childController: canvasContainer)
        debugSettingsNativeViewsForPinsSubscriber?.cancel()
        debugSettingsNativeViewsForPinsSubscriber = nil
        userSettingsShowArchivedPinsSubscriber?.cancel()
        userSettingsShowArchivedPinsSubscriber = nil
        currentCanvasObservation?.invalidate()
        currentCanvasObservation = nil
        canvasNotificationToken?.invalidate()
        canvasNotificationToken = nil
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
        reloadGeometriesPinsDisplay(
            useNativeViews: debugSettings.nativeViewsForPins,
            showArchivedCollaborations: userSettings.showArchivedCollaborations
        ) {
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
