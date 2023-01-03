import Foundation
import UIKit

/// Manages the flow of adding new pin (select pin type and place on the canvas)
class AddPinFlowController {
    unowned let model: ProjectModel
    unowned let canvasContainer: CanvasContainerViewController

    /// called when the flow finishes, if pin was added it's passed as optional Collaboration. If cancelled nil is passed
    var onStop: ((Collaboration?) -> Void)?

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
    init(model: ProjectModel, canvasContainer: CanvasContainerViewController) {
        self.model = model
        self.canvasContainer = canvasContainer
    }

    /// Presents the pin type selection, if anything selected the call the onStarted callback.
    func start(onStarted: @escaping (Bool) -> Void) {
        // select pin type
        SelectPinTypeCardViewController(onPinTypeSelected: { [weak self] pinType in
            onStarted(pinType != nil)
            if let pinType = pinType {
                self?.selectPinLocation(pinType: pinType)
            }
        })
        .installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    /// Adapt the UI for the location selection
    private func selectPinLocation(pinType: PinType) {
        canvasDelegateId = canvasContainer.pdfCanvasViewController.addDelegate(self)
        showTopViewController(pinType: pinType)
        showConfirmationCard()
        showPanAndZoomIndicatorView()
        showCanvasSelectorButton()
        showPins()
        showPinView(pinType: pinType)
    }

    /// remove the photo location selection views/handlers
    private func dismissPhotoLocationSelectionUI() {
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
    private func showTopViewController(pinType: PinType) {
        let topViewController = TopViewController(
            iconName: "mappin.and.ellipse",
            title: String(localized: pinType == .photo ? "Add Photo Pin" : "Add Task Pin")
        )
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
            self?.dismissPhotoLocationSelectionUI()
            self?.onStop?(nil)
        }
//        confirmationCardVC!.onConfirm = { _ in
//            // TODO: 306 add collaboration
//        }
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
        pinsDisplay = DebugSettings().nativeViewsForPins
            ? GeometriesViewAnnotationPinsDisplay(
                canvas: model.currentCanvas,
                canvasViewController: canvasContainer.pdfCanvasViewController,
                selectionEnabled: false,
                deselectOnCanvasTap: false,
                geometryPinDisplayOptionsProvider: PinDisplayOptions.addPinDisplayOptionsProvider
            )
            : GeometriesAnnotationPinsDisplay(
                canvas: model.currentCanvas,
                canvasViewController: canvasContainer.pdfCanvasViewController,
                selectionEnabled: false,
                deselectOnCanvasTap: false,
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
    private func showPinView(pinType: PinType) {
        let pin: PinImage
        if pinType == .photo {
            pin = .pinPhoto(count: 0)
        } else {
            /// select color for task pin
            let pinColor: UIColor
            if let initialStatus = model.mainRealm.objects(Status.self).first(where: { $0.isInitial }) {
                pinColor = initialStatus.color
            } else {
                pinColor = .Primary_Blue_04
            }
            pin = .pinTask(color: pinColor)
        }
        pinView = UIImageView(image: pin.image)
        canvasContainer.content.addSubview(pinView!)
        pinView!.snp.makeConstraints { make in
            make.center.equalToSuperview()
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
