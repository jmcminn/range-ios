import AVFoundation
import UIKit

/// Manages the flow of taking photo(s) and assigning their locations on the map
class PhotoFlowController {
    unowned let projectFlow: ProjectFlowController

    var pinView: UIView?
    var onStop: (() -> Void)?

    ///
    /// - Parameters: projectFlow - used to control the UI state of the main project flow,
    /// as the photo flow operates on the same base map(pdf) view
    init(projectFlow: ProjectFlowController) {
        self.projectFlow = projectFlow
    }

    func start() {
        checkPermissionsAndShowCamera()
    }

    func stop() {
        restoreProjectFlowControlViews()
        onStop?()
    }

    // TODO: this may need some sort of state description in ProjectFlowController, like an enum of views and their state, so we can save + restore it
    private func hideProjectFlowControlViews() {
        projectFlow.actionCardVC.hideCard(animated: true)
    }

    private func restoreProjectFlowControlViews() {
        projectFlow.actionCardVC.showCard(animated: true)
    }

    private func checkPermissionsAndShowCamera() {
        Task {
            let cameraPermissions = await checkForCameraPermissions()
            switch cameraPermissions {
            case .authorized:
                DispatchQueue.main.async {
                    self.showCamera()
                }
            case .notAuthorized:
                // User just denied the access, no point in showing another alert
                break
            case .previouslyDenied:
                // Present alert with option to go to Settings and enable the Camera
                DispatchQueue.main.async {
                    self.projectFlow.present(self.noCameraAccessAlert, animated: true)
                }
            }
        }
    }

    private func showCamera() {
        let vc = CameraHostingController()
        vc.modalPresentationStyle = .fullScreen
        vc.onClose = {
            vc.dismiss(animated: true)
            self.stop()
        }
        vc.onPhotoTaken = { [weak self] data in
            if let data = data, let image = UIImage(data: data) {
                vc.dismiss(animated: true)
                self?.onPhotoTaken(photo: image)
            } else {
                // TODO: show alert or just log?
            }
        }
        // TODO: do we want to present as a card?
//         vc.installModalCardDisplayController(cardConfig: CardConfiguration(initialCardPosition: .max))

        projectFlow.present(vc, animated: true) {
            self.hideProjectFlowControlViews()
        }
    }

    private func onPhotoTaken(photo: UIImage) {
        showPin(forImage: photo)
        showPhotoLocationCard()
    }

    private func showPin(forImage image: UIImage) {
        // hide previous pin
        pinView?.removeFromSuperview()

        let pin = createPhotoPin(fromImage: image)
        // TODO: direct access to projectFlow views and cards seems wrong
        projectFlow.contentContainer.addSubview(pin)
        pin.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            // center pin tip on the screen center (the asset has insets defined to ignore shadow)
            make.bottom.equalTo(projectFlow.view.snp.centerY)
        }
        pinView = pin
    }

    private func showPhotoLocationCard() {
        let vc = AddPhotoLocationCardViewController()
        vc.onCancel = { [weak self] in
            guard let self = self else { return }
            self.pinView?.removeFromSuperview()
            vc.hideCard(animated: true) {
                self.projectFlow.removeCard(cardViewController: vc)
            }
            self.stop()
        }
        vc.onConfirm = { [weak self] in
            guard let self = self else { return }
            vc.hideCard(animated: true) {
                self.projectFlow.removeCard(cardViewController: vc)
            }
            self.stop()
        }
        projectFlow.installCard(
            cardViewController: vc,
            inView: projectFlow.controlsContainer,
            cardConfig: CardConfiguration(showSafeAreaBlur: true)
        )
        vc.showCard(animated: true)
    }
}

/// Camera permissions
private extension PhotoFlowController {
    enum PermissionsResult {
        case authorized
        case notAuthorized
        case previouslyDenied // already denied when calling requestAccess
    }

    func checkForCameraPermissions() async -> PermissionsResult {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            return .authorized
        case .notDetermined:
            // The user has not yet been presented with the option to grant video access.
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .authorized : .notAuthorized
        default:
            // The user has previously denied access.
            return .previouslyDenied
        }
    }

    var noCameraAccessAlert: UIAlertController {
        let alertController = UIAlertController(
            title: "Camera Access",
            message: "Range doesn't have access to use your camera, please update your privacy settings.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            alertController.dismiss(animated: true)
        })
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            alertController.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl) { success in
                        print("Settings opened: \(success)")
                    }
                }
            })
        }
        return alertController
    }
}
