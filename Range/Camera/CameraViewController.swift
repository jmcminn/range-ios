import SwiftUI
import UIKit

// A UIHostingController defines a UIViewController (from UIKit as opposed to SwiftUI) that nonetheless manages a
// SwiftUI view hierarchy
//
// ModalCardCoordinating allows the CameraView to be presented as a modal, nominally in minimum, partly-raised
// or full-screen sizes, but in fact CameraViewController overrides this behavior to allow only full-screen

/// A UIViewController whose view is a CameraView
/// It also owns and manages a CameraService and uses it to actually take photos
class CameraViewController: UIHostingController<CameraView>, ModalCardCoordinating {
    var onClose: (() -> Void)?
    var onPhotoTaken: ((UIImage) -> Void)?
    var modalCardDisplayController: ModalCardDisplayController?
    private let cameraService = CameraService()

    init() {
        super
            .init(rootView: CameraView(cameraService: cameraService, closeAction: {},
                                       takePhotoAction: {}))

        rootView = CameraView(
            cameraService: cameraService,
            closeAction: { [weak self] in
                self?.onClose?()
            }, takePhotoAction: { [weak self] in
                self?.takePhotoAction()
            }
        )
    }

    private func takePhotoAction() {
        guard let onPhotoTaken = onPhotoTaken else { return }
        cameraService.capturePhoto { [weak self] data in
            if let data = data, let image = UIImage(data: data) {
                onPhotoTaken(image)
            } else {
                self?.showCapturePhotoErrorAlert()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Display alert if CameraService configuration failed
    private func showCameraConfigurationErrorAlert() {
        let alertController = UIAlertController(
            title: "Camera Error",
            message: "Camera configuration failed. Either your device camera is not available or it's missing permissions.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Ok", style: .cancel) { _ in
            if let onClose = self.onClose {
                onClose()
            } else {
                alertController.dismiss(animated: true)
            }
        })
        present(alertController, animated: true)
    }

    private func showCapturePhotoErrorAlert() {
        let alertController = UIAlertController(
            title: "Camera Error",
            message: "Error while taking the photo, please try again.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
        present(alertController, animated: true)
    }

    // configure the CameraService when the view loads
    override func viewDidLoad() {
        super.viewDidLoad()
        cameraService.configure { [weak self] sessionSetupResult in
            if sessionSetupResult == .configurationFailed {
                self?.showCameraConfigurationErrorAlert()
            }
        }
    }

    // start the CameraService before the view appears
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraService.start()
    }

    // stop the CameraService before the view disappears
    override func viewWillDisappear(_ animated: Bool) {
        cameraService.stop()
        super.viewWillDisappear(animated)
    }

    override dynamic var preferredStatusBarStyle: UIStatusBarStyle {
        UIStatusBarStyle.lightContent
    }
}

// CardPresentable would normally allow a view to appear as a minimum, partly-raised, or full-screen window,
// but in this case really only allows full-screen and dismisses the view in the minimum position
extension CameraViewController: CardPresentable {
    func height(forWidth _: CGFloat, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .min {
            return 0
        } else if cardPosition == .medium {
            return -1 // not supported
        } else {
            return CGFloat.greatestFiniteMagnitude
        }
    }

    func cardDidChangePosition(_ position: CardPosition) {
        if position == .min {
            dismiss(animated: false)
        }
    }
}
