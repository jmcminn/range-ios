import AVFoundation
import SnapKit
import UIKit

/// Main view controller for displaying a project.
/// It manages the UI state of project and all view transitions.
final class ProjectFlowController: UIViewController {
    
    let pdfSource: PDFSource
    
    init(pdfSource: PDFSource) {
        self.pdfSource = pdfSource
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func start() {
        showSource()
    }
    
    fileprivate func showSource() {
        let sourceVC = AnnotatedPDFViewController(pdfSource: pdfSource)
        add(childController: sourceVC)
        
        showActionCard()
    }
    
    fileprivate func showActionCard() {
        let vc = ProjectActionCardViewController()
        vc.onCamera = { [weak self] in
            guard let self = self else { return }
            self.showCamera(fromViewController: vc)
        }
        vc.installCardDisplayController(cardConfig: CardConfiguration(showSafeAreaBlur: true))
        self.present(vc, animated: true)
    }
    
    
    fileprivate func showCamera(fromViewController fromVC: UIViewController) {
        Task {
            let cameraPermissions = await checkForCameraPermissions()
            
            if cameraPermissions == .previouslyDenied {
                // Present alert with option to go to Settings and enable the Camera
                let alertController = UIAlertController(
                    title: "Camera Access",
                    message: "Range doesn't have access to use your camera, please update your privacy settings.",
                    preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                    alertController.dismiss(animated: true)
                }))
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    alertController.addAction(UIAlertAction(title: "Settings", style: .default) { _  in
                        if UIApplication.shared.canOpenURL(settingsUrl) {
                            UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                                print("Settings opened: \(success)") // Prints true
                            })
                        }
                    })
                }
                fromVC.present(alertController, animated: true)
            } else if cameraPermissions == .notAuthorized {
                // User just denied the access, no point in showing another alert
            } else {
                // Authorized to use camera
                let vc = CameraHostingController()
                vc.modalPresentationStyle = .fullScreen
                vc.onClose = {
                    vc.dismiss(animated: true)
                }
                vc.onPhotoTaken = { data in
                    if let data = data {
                        vc.dismiss(animated: true)
                        let imageView = UIImageView(image: UIImage(data: data)!.imageResized(toWidth: 100))
                        self.view.addSubview(imageView)
                        imageView.snp.makeConstraints { make in
                            make.center.equalToSuperview()
                        }
                    } else {
                        // TODO: error?
                    }
                }
                // TODO: do we want to present as a card?
                //        vc.installCardDisplayController(cardConfig: CardConfiguration(initialCardPosition: .max))
                fromVC.present(vc, animated: true)
            }
        }
    }
}

/// Camera permissions
extension ProjectFlowController {
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
}
