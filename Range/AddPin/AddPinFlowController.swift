import Foundation
import UIKit

/// Manages the flow of adding new pin or moving an existing collaboration
class AddPinFlowController {
    unowned let model: ProjectModel
    unowned let canvasContainer: CanvasContainerViewController
    private let controls: ProjectCanvasControls

    private var pinTypeOption: PinTypeOption?

    /// in .copyTask mode this is the collaboration that we want to copy data from:
    private var taskToCopy: Collaboration?

    /// called when the flow finishes, if pin was added the id of the created geometry is returned. If cancelled nil is passed
    var onStop: ((String?, PinTypeOption?) -> Void)?

    private var confirmationCardVC: AddPinConfirmationViewController?
    private var pinsDisplay: GeometriesPinsDisplay?
    /// the pin shown in the center to indicate where the pin is being placed
    private var pinView: UIView?

    /// id of registered delegate
    var canvasDelegateId: UUID?

    /// To observed changes in model.currentCanvas
    private var canvasObservation: NSKeyValueObservation?

    /// - Parameters:
    ///     - model: - the project model
    ///     - canvas: - the flow will operate on this canvas
    init(model: ProjectModel, canvasContainer: CanvasContainerViewController) {
        self.model = model
        self.canvasContainer = canvasContainer
        controls = ProjectCanvasControls(canvasContainer: canvasContainer)
    }

    deinit {
        controls.removeFromSuperview()
    }

    /// Show the UI for pin selection
    func start() {
        selectPinTypeOption()
    }

    private func selectPinTypeOption() {
        SelectPinTypeCardViewController(onPinTypeSelected: { [weak self] pinTypeOption in
            guard let self = self else { return }
            if let pinTypeOption = pinTypeOption {
                self.pinTypeOption = pinTypeOption
                if pinTypeOption == .copyTask {
                    self.selectTaskToCopy()
                } else {
                    self.showPinPlacementUI()
                }
            } else {
                self.onStop?(nil, nil)
            }
        })
        .installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    private func selectTaskToCopy() {
        let copyTaskCardVC = CopyTaskCardViewController(projectModel: model)
        copyTaskCardVC.onTaskSelected = { [weak self] task in
            guard let self = self else { return }
            self.taskToCopy = task
            self.showPinPlacementUI()
        }
        copyTaskCardVC.onAddTaskPin = { [weak self] in
            guard let self = self else { return }
            self.pinTypeOption = .createTask
            self.showPinPlacementUI()
        }
        copyTaskCardVC.onClose = { [weak self] in
            self?.onStop?(nil, nil)
        }
        copyTaskCardVC.installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    private func showPinPlacementUI() {
        canvasDelegateId = canvasContainer.canvasViewController.addDelegate(self)
        showTopViewController()
        showConfirmationCard()
        controls.showPanAndZoomIndicatorView(aboveView: confirmationCardVC!.view)
        controls.showCanvasSelectorButton(aboveView: confirmationCardVC!.view)
        controls.showCanvasSourceSelectorButton(aboveView: controls.canvasSelectorButton!)
        controls.canvasSourceSelectorButton?.isHidden = model.currentCanvas.canvasSources.count <= 1
        showPins()
        showPinView()
        canvasObservation = model.observe(\.currentCanvas) { [weak self] _, _ in
            guard let self = self else { return }
            self.reloadGeometriesPinsDisplay()
            self.controls.canvasSourceSelectorButton?.isHidden = self.model.currentCanvas.canvasSources.count <= 1
        }
    }

    /// remove the photo location selection views/handlers
    private func stop() {
        if let canvasDelegateId = canvasDelegateId {
            canvasContainer.canvasViewController.removeDelegate(id: canvasDelegateId)
        }
        if let confirmationCardVC = confirmationCardVC {
            confirmationCardVC.hideCard(animated: true) {
                self.canvasContainer.removeCard(cardViewController: confirmationCardVC)
            }
        }
        controls.hideTopViewController(animated: false)
        controls.hidePanAndZoomIndicatorView(animated: false)
        pinsDisplay?.stop()
        pinsDisplay = nil
        canvasObservation?.invalidate()
        canvasObservation = nil
        controls.hideCanvasSelectorButton()
        controls.hideCanvasSourceSelectorButton()
        pinView?.removeFromSuperview()
        pinView = nil
    }

    /// shows the view controller covering the top of of the screen
    private func showTopViewController() {
        guard let pinTypeOption = pinTypeOption else {
            fatalError("showTopViewController called when pinTypeOption is nil")
        }

        let title: String
        switch pinTypeOption {
        case .createPhoto: title = String(localized: "Add Photo Pin")
        case .createTask: title = String(localized: "Add Task Pin")
        case .copyTask: title = String(localized: "Add Task Pin")
        }
        controls.showTopViewController(iconName: "mappin.and.ellipse", title: title, animated: true)
    }

    /// Presents a card with cancel/confirm and registers callbacks for user actions
    private func showConfirmationCard() {
        confirmationCardVC = AddPinConfirmationViewController()
        confirmationCardVC!.onCancel = { [weak self] in
            self?.stop()
            self?.onStop?(nil, nil)
        }
        confirmationCardVC!.onConfirm = { [weak self] in
            self?.createCollaborationAndStop()
        }
        canvasContainer.installCard(
            cardViewController: confirmationCardVC!,
            inView: canvasContainer.controls,
            cardConfig: CardConfiguration(interactive: false, showSafeAreaBlur: true)
        )
        confirmationCardVC!.showCard(animated: true)
    }

    /// Starts the pin handler that adds the pins to the canvas and allows for the selection
    private func showPins() {
        createPinsDisplay()
        pinsDisplay?.start(onInitialLoad: nil)
    }

    /// Reload the geometries pins display.
    /// It stops the current pins display, creates a new one and starts it if the previous one was started (maybe it was temporarily stopped,
    /// then we need the new one to be stopped too)
    private func reloadGeometriesPinsDisplay() {
        let start = pinsDisplay?.started ?? false
        pinsDisplay?.stop()
        createPinsDisplay()
        if start {
            pinsDisplay?.start(onInitialLoad: nil)
        }
    }

    private func createPinsDisplay() {
        pinsDisplay = _createGeometriesPinsDisplay(
            usingNativeViews: DebugSettings().nativeViewsForPins,
            canvas: model.currentCanvas,
            canvasViewController: canvasContainer.canvasViewController,
            selectionEnabled: false,
            deselectOnCanvasTap: false,
            ignoredGeometryId: nil,
            canvasFilters: canvasContainer.canvasFilters,
            geometryPinDisplayOptionsProvider: PinDisplayOptions.addPinDisplayOptionsProvider
        )
    }

    /// shows the pin view in the center of the screen
    private func showPinView() {
        guard let pinTypeOption = pinTypeOption else {
            fatalError("showPinView called when pinTypeOption is nil")
        }
        // prepare collaboration depending on the pin type option, so we can use PinDisplayOptions
        // to get the pin for given collaboration
        let collaboration: Collaboration
        switch pinTypeOption {
        case .createPhoto:
            // empty collaboration
            collaboration = Collaboration(placeholderId: "")
        case .createTask, .copyTask:
            // empty collaboration with initial status
            collaboration = Collaboration(placeholderId: "")
            collaboration.status = model.mainRealm.objects(Status.self).first(where: { $0.isInitial })
        }
        let pinDisplayOptions = PinDisplayOptions.regularPinDisplayOptionsProvider(
            collaboration: collaboration,
            selected: true,
            anythingSelected: false
        )
        pinView = UIImageView(image: pinDisplayOptions.pinImage.image)
        canvasContainer.content.addSubview(pinView!)
        pinView!.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            if pinDisplayOptions.anchor == .bottom {
                make.bottom.equalTo(canvasContainer.content.snp.centerY).offset(-pinDisplayOptions.offsetY)
            } else {
                make.centerY.equalToSuperview().offset(-pinDisplayOptions.offsetY)
            }
        }
    }

    private func createCollaborationAndStop() {
        let geometryId = generateRealmId()
        Task {
            do {
                defer {
                    DispatchQueue.main.async {
                        self.stop()
                        self.onStop?(geometryId, self.pinTypeOption)
                    }
                }
                try await runCommand(geometryId: geometryId)
                UserDefaults.lastPhotoPinId = geometryId
            } catch {
                DispatchQueue.main.async {
                    ToastWindow.shared.showError(text: "Failed to create the collaboration")
                }
            }
        }
    }

    @MainActor
    private func runCommand(geometryId: String) async throws {
        guard let pinTypeOption = pinTypeOption else {
            fatalError("runCommand called when pinTypeOption is nil")
        }
        let coordinates = canvasContainer.annotationsMapView.cameraState.center
        let canvas = model.currentCanvas!
        let command: Command
        switch pinTypeOption {
        case .createPhoto:
            command = try await model.createCollaboration(
                at: coordinates,
                in: canvas,
                withGeometryId: geometryId,
                isTask: false
            )
        case .createTask:
            command = try await model.createCollaboration(
                at: coordinates,
                in: canvas,
                withGeometryId: geometryId,
                isTask: true
            )
        case .copyTask:
            guard let taskToCopy = taskToCopy else {
                fatalError("task to copy not selected")
            }
            command = try await model.createCollaboration(
                at: coordinates,
                in: canvas,
                withGeometryId: geometryId,
                isTask: true,
                name: taskToCopy.name,
                collaborationDescription: taskToCopy.collaborationDescription,
                assignee: taskToCopy.assignee,
                dueDate: taskToCopy.dueDateTimestamp,
                tags: taskToCopy.tags.map(TagViewModel.init(fromTag:))
            )
            UserDefaults.addLastCopiedTask(taskToCopy.id, forProjectId: model.projectId)
        }
        try await model.run(command)
    }
}

/// CanvasViewControllerDelegate
extension AddPinFlowController: CanvasViewControllerDelegate {
    func canvasCameraChanged(reason: CanvasCameraChangeReason) {
        if reason == .pan || reason == .zoom {
            controls.hidePanAndZoomIndicatorView(animated: true)
        }
    }

    func canvasTapRecognized(at _: CGPoint) {}
}
