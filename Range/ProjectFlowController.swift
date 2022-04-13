import AVFoundation
import SnapKit
import UIKit

/// Main view controller for displaying a project.
/// It manages the UI state of project and all view transitions.
final class ProjectFlowController: UIViewController {
    let pdfSource: PDFSource
    lazy var actionCardVC = installActionCardVC()
    lazy var bottomBlurView = setupBottomBlur()
    var pinView: UIView?

    init(pdfSource: PDFSource) {
        self.pdfSource = pdfSource
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func start() {
        showSource()
    }

    fileprivate func showSource() {
        let sourceVC = AnnotatedPDFViewController(pdfSource: pdfSource)
        add(childController: sourceVC)

        actionCardVC.showCard(animated: true)
        bottomBlurView.isHidden = false
    }

    fileprivate func setupBottomBlur() -> UIView {
        let blur = UIBlurEffect(style: .regular)
        let blurView = UIVisualEffectView(effect: blur)
        view.addSubview(blurView)
        blurView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(self.view.safeAreaInsets.bottom)
        }
        return blurView
    }

    fileprivate func installActionCardVC() -> ProjectActionCardViewController {
        let vc = ProjectActionCardViewController()
        vc.onCamera = { [weak self] in
            guard let self = self else { return }
            self.checkPermissionsAndShowCamera()
        }
        installCard(cardViewController: vc, cardConfig: CardConfiguration(showSafeAreaBlur: true))
        return vc
    }

    fileprivate func checkPermissionsAndShowCamera() {
        Task {
            let cameraPermissions = await checkForCameraPermissions()
            switch cameraPermissions {
            case .authorized:
                showCamera()
            case .notAuthorized:
                // User just denied the access, no point in showing another alert
                break
            case .previouslyDenied:
                // Present alert with option to go to Settings and enable the Camera
                self.present(noCameraAccessAlert, animated: true)
            }
        }
    }

    fileprivate func showCamera() {
        let vc = CameraHostingController()
        vc.modalPresentationStyle = .fullScreen
        vc.onClose = {
            vc.dismiss(animated: true)
        }
        vc.onPhotoTaken = { [weak self] data in
            if let data = data, let image = UIImage(data: data) {
                guard let self = self else { return }
                self.showPin(forImage: image)
                vc.dismiss(animated: true)
            } else {
                // TODO: show alert or just log?
            }
        }
        // TODO: do we want to present as a card?
        // vc.installModalCardDisplayController(cardConfig: CardConfiguration(initialCardPosition: .max))

        present(vc, animated: true)
    }

    fileprivate func showPin(forImage image: UIImage) {
        // hide previous pin
        pinView?.removeFromSuperview()

        let pin = createPhotoPin(fromImage: image)
        view.addSubview(pin)
        pin.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            // center pin tip on the screen center (the asset has insets defined to ignore shadow)
            make.bottom.equalTo(self.view.snp.centerY)
        }
        pinView = pin
    }
}

/// Camera permissions
private extension ProjectFlowController {
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
