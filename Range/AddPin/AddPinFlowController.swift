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
        // TODO: 306 here
//        canvasDelegateId = canvasContainer.pdfCanvasViewController.addDelegate(self)
        showTopViewController(pinType: pinType)
        showConfirmationCard()
//        showPanAndZoomIndicatorView()
//        showCanvasSelectorButton()
        showPins()
    }

    /// remove the photo location selection views/handlers
    private func dismissPhotoLocationSelectionUI() {
        // TODO: 306
//        if let canvasDelegateId = canvasDelegateId {
//            canvasContainer.pdfCanvasViewController.removeDelegate(id: canvasDelegateId)
//        }
        if let confirmationCardVC = confirmationCardVC {
            confirmationCardVC.hideCard(animated: true) {
                self.canvasContainer.removeCard(cardViewController: confirmationCardVC)
            }
        }
        hideTopViewController()
        pinsDisplay?.stop()
        pinsDisplay = nil
//        panAndZoomIndicatorView?.removeFromSuperview()
//        canvasObservation?.invalidate()
//        canvasObservation = nil
//        hideCanvasSelectorButton()
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

    private func showPins() {
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
        pinsDisplay?.start(onInitialLoad: nil)
    }
}
