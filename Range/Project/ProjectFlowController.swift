import Combine
import OSLog
import SnapKit
import SwiftUI
import UIKit

/// Main view controller for displaying a project.
/// It manages the UI state of project and all view transitions.
final class ProjectFlowController: UIViewController {
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
    lazy var actionCardVC = installActionCardVC()
    var pinsDisplay: GeometriesPinsDisplay?
    var debugSettingsButton: RoundShadowButton!

    var addPhotoFlow: AddPhotoFlowController?

    var started = false
    var onBack: (() -> Void)?

    /// Initialize ProjectFlowController
    /// This can throw if project model cannot be loaded or started
    ///
    /// - Parameters:
    ///     - userId: range id of the logged in user
    ///     - projectId: id of the project
    init(
        userId: String,
        demoProject: DemoProject,
        imageCaches: ImageCaches,
        pendingUploadsModel: PendingUploadsModel,
        pendingActionsModel: PendingActionsModel
    ) async throws {
        self.imageCaches = imageCaches
        model = try ProjectModel(
            userId: userId,
            projectId: demoProject.id,
            imageCaches: imageCaches,
            pendingUploadsModel: pendingUploadsModel,
            pendingActionsModel: pendingActionsModel
        )
        model.demoCanvas = demoProject.canvas
        try await model.start()

        modelFirestoreSync = ProjectModelFirestoreSync(model: model)
        await modelFirestoreSync.start()

        try model.loadProject(initialCanvasId: demoProject.canvas.id)

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
        showDefaultCanvasUI(animated: false)
        collaborationFlow.start()
        observeDebugSettings()
    }

    private func observeDebugSettings() {
        debugSettingsNativeViewsForPinsSubscriber = debugSettings.$nativeViewsForPins
            .sink { [weak self] useNativeViews in
                guard let self = self else { return }
                self.pinsDisplay?.stop()
                self.createGeometriesPinsDisplay(useNativeViews: useNativeViews)
                self.pinsDisplay?.start(onInitialLoad: nil)
            }
    }

    private func createGeometriesPinsDisplay(useNativeViews: Bool) {
        pinsDisplay = useNativeViews
            ? GeometriesViewAnnotationPinsDisplay(
                canvasViewController: canvasContainer.pdfCanvasViewController,
                deselectOnCanvasTap: true,
                geometryPinDisplayOptionsProvider: PinDisplayOptions.regularPinDisplayOptionsProvider
            )
            : GeometriesAnnotationPinsDisplay(canvasViewController:
                canvasContainer.pdfCanvasViewController,
                deselectOnCanvasTap: true,
                geometryPinDisplayOptionsProvider: PinDisplayOptions
                    .regularPinDisplayOptionsProvider)
        pinsDisplay?.onSelectedPinChange = { [weak self] pinPoint in
            if let geometryId = pinPoint?.id {
                self?.collaborationFlow.showCollaborationWindow(forGeometry: geometryId, animated: true)
            } else {
                self?.collaborationFlow.hideCollaborationWindow(animated: true)
            }
        }
    }

    func stop() {
        collaborationFlow.stop()
        pinsDisplay?.stop()
        canvasContainer.removeCard(cardViewController: actionCardVC)
        remove(childController: canvasContainer)
        debugSettingsNativeViewsForPinsSubscriber?.cancel()
        debugSettingsNativeViewsForPinsSubscriber = nil
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
        showDebugSettingsButton()
        pinsDisplay?.start(onInitialLoad: nil)
    }

    /// Hide the default UI elements when viewing the canvas
    fileprivate func hideDefaultCanvasUI(animated: Bool = true) {
        actionCardVC.hideCard(animated: animated)
        hideDebugSettingsButton()
        pinsDisplay?.stop()
    }

    // TODO: this should be hidden in the production version
    /// Shows a button that shows the debug settings view
    fileprivate func showDebugSettingsButton() {
        if debugSettingsButton == nil {
            debugSettingsButton = RoundShadowButton(image: UIImage(systemName: "gearshape") ?? UIImage())
            canvasContainer.controls.addSubview(debugSettingsButton)
            debugSettingsButton.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-10)
                make.centerY.equalToSuperview()
            }
            debugSettingsButton.addTarget(self, action: #selector(showDebugSettingsAction), for: .touchUpInside)
        }
        debugSettingsButton.isHidden = false
    }

    fileprivate func hideDebugSettingsButton() {
        debugSettingsButton.isHidden = true
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

    fileprivate func installActionCardVC() -> ProjectActionCardViewController {
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
        ]
        let vc = ProjectActionCardViewController(actions: additionalCardActions)
        vc.onCamera = { [weak self] in
            self?.startAddPhotoFlow()
        }
        vc.onAddMarker = { [weak self] in
            self?.addMarker()
        }
        canvasContainer.installCard(cardViewController: vc, inView: canvasContainer.controls)
        return vc
    }
}

// MARK: - actions

extension ProjectFlowController {
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
        ).installAndShowCard(in: canvasContainer)
    }
}
