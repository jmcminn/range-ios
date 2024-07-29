import Foundation
import UIKit

/// Manages the flow of moving an existing collaboration
class MovePinFlowController {
    unowned let model: ProjectModel
    private let collaboration: Collaboration
    unowned let canvasContainer: CanvasContainerViewController
    private let controls: ProjectCanvasControls

    /// called when the flow finishes, if pin was added the id of the created geometry is returned. If cancelled nil is passed
    var onStop: ((String?) -> Void)?

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
    init(model: ProjectModel, collaboration: Collaboration, canvasContainer: CanvasContainerViewController) {
        self.model = model
        self.collaboration = collaboration
        self.canvasContainer = canvasContainer
        controls = ProjectCanvasControls(canvasContainer: canvasContainer)
    }

    /// Show the UI for pin selection
    func start() {
        canvasDelegateId = canvasContainer.canvasViewController.addDelegate(self)
        controls.showTopViewController(iconName: "mappin.and.ellipse", title: "Update Pin Location", animated: true)
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
        controls.removeFromSuperview()
    }

    /// Presents a card with cancel/confirm and registers callbacks for user actions
    private func showConfirmationCard() {
        confirmationCardVC = AddPinConfirmationViewController()
        confirmationCardVC!.onCancel = { [weak self] in
            self?.stop()
            self?.onStop?(nil)
        }
        confirmationCardVC!.onConfirm = { [weak self] in
            self?.moveCollaborationAndStop()
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
        // When moving a collaboration we display it's pin using the separate `pinView` so we need
        // to hide the pin on canvas
        let ignoredGeometryId = collaboration.geometry.first?.id
        pinsDisplay = _createGeometriesPinsDisplay(
            usingNativeViews: _debugSettings.nativeViewsForPins,
            canvas: model.currentCanvas,
            canvasViewController: canvasContainer.canvasViewController,
            selectionEnabled: false,
            deselectOnCanvasTap: false,
            ignoredGeometryId: ignoredGeometryId,
            canvasFilters: canvasContainer.canvasFilters,
            geometryPinDisplayOptionsProvider: PinDisplayOptions.addPinDisplayOptionsProvider
        )
    }

    /// shows the pin view in the center of the screen
    private func showPinView() {
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

    private func moveCollaborationAndStop() {
        let geometryId = generateRealmId()
        Task { @MainActor in
            do {
                defer {
                    DispatchQueue.main.async {
                        self.stop()
                        self.onStop?(geometryId)
                    }
                }
                let coordinates = canvasContainer.annotationsMapView.mapboxMap.cameraState.center
                let canvas = model.currentCanvas!
                let command = try model.update(
                    coordinates: coordinates,
                    andCanvas: canvas,
                    forCollaboration: collaboration
                )
                try await model.run(command)
            } catch {
                DispatchQueue.main.async {
                    ToastWindow.shared.showError(text: "Failed to move the pin")
                }
            }
        }
    }
}

/// CanvasViewControllerDelegate
extension MovePinFlowController: CanvasViewControllerDelegate {
    func canvasCameraChanged(reason: CanvasCameraChangeReason) {
        if reason == .pan || reason == .zoom {
            controls.hidePanAndZoomIndicatorView(animated: true)
        }
    }

    func canvasTapRecognized(at _: CGPoint) {}
    func canvasLongPressRecognized(at _: CGPoint) {}
}
