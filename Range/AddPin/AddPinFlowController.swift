import Foundation

/// Manages the flow of adding new pin (select pin type and place on the canvas)
class AddPinFlowController {
    unowned let model: ProjectModel
    unowned let canvasContainer: CanvasContainerViewController

    /// called when the flow finishes, if pin was added it's passed as optional Collaboration. If cancelled nil is passed
    var onStop: ((Collaboration?) -> Void)?

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
        SelectPinTypeCardViewController(onPinTypeSelected: { pinType in
            onStarted(pinType != nil)
            if let pinType = pinType {
                print("TODO: 306 Pin type: \(pinType)")
            }
        })
        .installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }
}
