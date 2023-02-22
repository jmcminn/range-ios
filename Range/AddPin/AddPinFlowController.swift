import Foundation
import UIKit

/// Manages the flow of adding new pin or moving an existing collaboration
class AddPinFlowController {
    enum Mode {
        case add(PinType)
        case move(Collaboration)
    }

    private let mode: Mode
    unowned let model: ProjectModel
    unowned let canvasContainer: CanvasContainerViewController

    /// called when the flow finishes, if pin was added the id of the created geometry is returned. If cancelled nil is passed
    var onStop: ((String?) -> Void)?

    private var topViewController: TopViewController?
    private var confirmationCardVC: AddPinConfirmationViewController?
    private var pinsDisplay: GeometriesPinsDisplay?
    private var panAndZoomIndicatorView: ToastView?
    private var canvasSelectorButton: RoundShadowButton?
    /// the pin shown in the center to indicate where the pin is being placed
    private var pinView: UIView?

    /// id of registered delegate
    var canvasDelegateId: UUID?

    /// To observed changes in model.currentCanvas
    private var canvasObservation: NSKeyValueObservation?

    /// - Parameters:
    ///     - model: - the project model
    ///     - canvas: - the flow will operate on this canvas
    init(model: ProjectModel, canvasContainer: CanvasContainerViewController, mode: Mode) {
        self.model = model
        self.canvasContainer = canvasContainer
        self.mode = mode
    }

    /// Show the UI for pin selection
    func start() {
        canvasDelegateId = canvasContainer.pdfCanvasViewController.addDelegate(self)
        showTopViewController()
        showConfirmationCard()
        showPanAndZoomIndicatorView()
        showCanvasSelectorButton()
        showPins()
        showPinView()
    }

    /// remove the photo location selection views/handlers
    private func stop() {
        if let canvasDelegateId = canvasDelegateId {
            canvasContainer.pdfCanvasViewController.removeDelegate(id: canvasDelegateId)
        }
        if let confirmationCardVC = confirmationCardVC {
            confirmationCardVC.hideCard(animated: true) {
                self.canvasContainer.removeCard(cardViewController: confirmationCardVC)
            }
        }
        hideTopViewController()
        pinsDisplay?.stop()
        pinsDisplay = nil
        panAndZoomIndicatorView?.removeFromSuperview()
        canvasObservation?.invalidate()
        canvasObservation = nil
        hideCanvasSelectorButton()
        pinView?.removeFromSuperview()
        pinView = nil
    }

    /// shows the view controller covering the top of of the screen
    private func showTopViewController() {
        let title: String
        switch mode {
        case .add(.photo): title = String(localized: "Add Photo Pin")
        case .add(.task): title = String(localized: "Add Task Pin")
        case .move: title = String(localized: "Update Pin Location")
        }
        let topViewController = TopViewController(iconName: "mappin.and.ellipse", title: title)
        canvasContainer.add(childController: topViewController, toView: canvasContainer.controls)
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

    /// Presents a card with cancel/confirm and registers callbacks for user actions
    private func showConfirmationCard() {
        confirmationCardVC = AddPinConfirmationViewController()
        confirmationCardVC!.onCancel = { [weak self] in
            self?.stop()
            self?.onStop?(nil)
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
        canvasObservation = model.observe(\.currentCanvas) { [weak self] _, _ in
            self?.reloadGeometriesPinsDisplay()
        }
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
        let ignoredGeometryId: String?
        if case let .move(c) = mode {
            ignoredGeometryId = c.feature.first?.geometry.first?.id
        } else {
            ignoredGeometryId = nil
        }
        pinsDisplay = DebugSettings().nativeViewsForPins
            ? GeometriesViewAnnotationPinsDisplay(
                canvas: model.currentCanvas,
                canvasViewController: canvasContainer.pdfCanvasViewController,
                selectionEnabled: false,
                deselectOnCanvasTap: false,
                ignoredGeometryId: ignoredGeometryId,
                showArchivedPins: UserSettings().showArchivedCollaborations,
                geometryPinDisplayOptionsProvider: PinDisplayOptions.addPinDisplayOptionsProvider
            )
            : GeometriesAnnotationPinsDisplay(
                canvas: model.currentCanvas,
                canvasViewController: canvasContainer.pdfCanvasViewController,
                selectionEnabled: false,
                deselectOnCanvasTap: false,
                ignoredGeometryId: ignoredGeometryId,
                showArchivedPins: UserSettings().showArchivedCollaborations,
                geometryPinDisplayOptionsProvider: PinDisplayOptions.addPinDisplayOptionsProvider
            )
    }

    private func showPanAndZoomIndicatorView() {
        panAndZoomIndicatorView = ToastView(
            iconName: "hand.point.up.left",
            text: "Pan and zoom to adjust the location",
            backgroundColor: .Neutral_10
        )
        canvasContainer.controls.addSubview(panAndZoomIndicatorView!)
        panAndZoomIndicatorView!.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.bottom.equalTo(confirmationCardVC!.view.snp.top).offset(-12)
        }
    }

    private func showCanvasSelectorButton() {
        canvasSelectorButton = RoundShadowButton(image: UIImage(systemName: "square.3.layers.3d") ?? UIImage())
        canvasSelectorButton!.addTarget(self, action: #selector(canvasSelectorButtonTapped), for: .touchUpInside)
        canvasContainer.controls.addSubview(canvasSelectorButton!)
        canvasSelectorButton!.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.bottom.equalTo(confirmationCardVC!.view.snp.top).offset(-12)
        }
    }

    private func hideCanvasSelectorButton() {
        canvasSelectorButton?.removeFromSuperview()
        canvasSelectorButton = nil
    }

    @objc private func canvasSelectorButtonTapped() {
        // send from canvasSelectorButton and not self, as AddPhotoFlowController is not in the
        // responder chain (it's not UIView or UIViewController)
        UIApplication.shared.sendAction(#selector(ProjectFlowActions.selectCanvasAction),
                                        to: nil, from: canvasSelectorButton, for: nil)
    }

    /// shows the pin view in the center of the screen
    private func showPinView() {
        // prepare collaboration depending on the mode, so we can use PinDisplayOptions to get the
        // pin for given collaboration
        let collaboration: Collaboration
        switch mode {
        case .add(.photo):
            // empty collaboration
            collaboration = Collaboration(placeholderId: "")
        case .add(.task):
            // empty collaboration with initial status
            collaboration = Collaboration(placeholderId: "")
            collaboration.status = model.mainRealm.objects(Status.self).first(where: { $0.isInitial })
        case let .move(c):
            collaboration = c
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
        let command: Command
        do {
            let coordinates = canvasContainer.annotationsMapView.cameraState.center
            let canvas = model.currentCanvas!

            switch mode {
            case .add(.photo):
                command = try model.createCollaboration(
                    at: coordinates,
                    in: canvas,
                    withGeometryId: geometryId,
                    isTask: false
                )
            case .add(.task):
                command = try model.createCollaboration(
                    at: coordinates,
                    in: canvas,
                    withGeometryId: geometryId,
                    isTask: true
                )
            case let .move(c):
                command = try model.update(coordinates: coordinates, andCanvas: canvas, forCollaboration: c)
            }
        } catch {
            ToastWindow.shared.showError(text: "Failed to create the collaboration")
            return
        }
        model.run(command) { [weak self] error in
            guard let self = self else { return }
            if error != nil {
                ToastWindow.shared.showError(text: "Failed to create the collaboration")
            } else {
                UserDefaults.lastPhotoPinId = geometryId
            }
            self.stop()
            self.onStop?(geometryId)
        }
    }
}

/// CanvasViewControllerDelegate
extension AddPinFlowController: CanvasViewControllerDelegate {
    func canvasCameraChanged(reason: CanvasCameraChangeReason) {
        if reason == .pan || reason == .zoom {
            guard let panAndZoomIndicator = panAndZoomIndicatorView else { return }
            UIView.animate(withDuration: 0.2,
                           animations: {
                               panAndZoomIndicator.alpha = 0
                           }, completion: { _ in
                               panAndZoomIndicator.removeFromSuperview()
                               self.panAndZoomIndicatorView = nil
                           })
        }
    }

    func canvasTapRecognized(at _: CGPoint) {}
}
