import Foundation
import UIKit

/// Manages the flow of adding new pin (select pin type and place on the canvas)
class AddPinFlowController {
    unowned let model: ProjectModel
    unowned let canvasContainer: CanvasContainerViewController

    /// called when the flow finishes, if pin was added it's passed as optional Collaboration. If cancelled nil is passed
    var onStop: ((Collaboration?) -> Void)?

    private var topViewController: TopViewController?

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
//        showConfirmationCard()
//        showPanAndZoomIndicatorView()
//        showCanvasSelectorButton()
//        showPins()
    }

    // TODO: 306 dismiss the location selection UI

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
}
