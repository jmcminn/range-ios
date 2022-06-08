import AVFoundation
import OSLog
import Turf
import UIKit

/// Manages the flow of taking photo(s) and assigning their locations on the map
class PhotoFlowController {
    unowned let model: ProjectModel
    unowned let canvasContainer: CanvasContainerViewController

    var onStop: (() -> Void)?
    var pinsHandler: AddPhotoPinsHandler?
    var topViewController: AddPhotoTopViewController?
    var confirmationCardVC: AddPhotoConfirmationViewController?
    var panAndZoomIndicatorView: PanAndZoomIndicatorView?

    /// id of registered delegate
    var canvasDelegateId: UUID?

    ///
    /// - Parameters:
    ///     - canvas: - the flow will operate on this canvas
    ///     - model: - the project model
    init(model: ProjectModel, canvasContainer: CanvasContainerViewController) {
        self.model = model
        self.canvasContainer = canvasContainer
    }

    /// Attempts to start the photo flow. Will callback the `onStarted`on the main queue with the result
    func start(onStarted: @escaping (Bool) -> Void) {
        Task {
            let started = await checkPermissionsAndShowCamera()
            DispatchQueue.main.async {
                onStarted(started)
            }
        }
    }

    func stop() {
        if let canvasDelegateId = canvasDelegateId {
            canvasContainer.pdfCanvasViewController.removeDelegate(id: canvasDelegateId)
        }
        if let confirmationCardVC = confirmationCardVC {
            confirmationCardVC.hideCard(animated: true) {
                self.canvasContainer.removeCard(cardViewController: confirmationCardVC)
            }
        }
        hideTopViewController()
        pinsHandler?.stop()
        panAndZoomIndicatorView?.removeFromSuperview()
        onStop?()
    }

    /// Returns `true` if camera was shown.
    private func checkPermissionsAndShowCamera() async -> Bool {
        let cameraPermissions = await checkForCameraPermissions()
        switch cameraPermissions {
        case .authorized:
            DispatchQueue.main.async {
                self.showCamera()
            }
            return true
        case .notAuthorized:
            // User just denied the access, no point in showing another alert
            return false
        case .previouslyDenied:
            // Present alert with option to go to Settings and enable the Camera
            DispatchQueue.main.async {
                self.canvasContainer.present(self.noCameraAccessAlert, animated: true)
            }
            return false
        }
    }

    private func showCamera() {
        let vc = CameraViewController()
        let navC = UINavigationController(rootViewController: vc)
        vc.onClose = { [weak self, weak vc] in
            vc?.dismiss(animated: true)
            self?.stop()
        }
        // TODO: 51 implement the flow
        vc.onPhotoTaken = { [weak self, weak vc, weak navC] data in
            if let self = self, let data = data, let image = UIImage(data: data) {
                let detailsVC = PhotoDetailsViewController(model: self.model, image: image)
                detailsVC.onBack = {
                    navC?.popToViewController(vc!, animated: true)
                }
                detailsVC.onNext = {
                    navC?.dismiss(animated: true)
                    self.onPhotoTaken(photo: image)
                }
                navC?.pushViewController(detailsVC, animated: true)
            } else {
                // TODO: show alert or just log?
            }
        }
//        vc.modalPresentationStyle = .fullScreen
        navC.modalPresentationStyle = .fullScreen
        // TODO: do we want to present as a card?
//         vc.installModalCardDisplayController(cardConfig: CardConfiguration(initialCardPosition: .max))

        canvasContainer.present(navC, animated: true)
    }

    private func onPhotoTaken(photo: UIImage) {
        canvasDelegateId = canvasContainer.pdfCanvasViewController.addDelegate(self)
        showTopViewController()
        showConfirmationCard()
        showPanAndZoomIndicatorView()
        showPins(forImage: photo)
    }

    private func showTopViewController() {
        let topViewController = AddPhotoTopViewController()
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

    private func showPins(forImage image: UIImage) {
        pinsHandler = AddPhotoPinsHandler(model: model, canvasContainer: canvasContainer, image: image)
        pinsHandler?.start()
    }

    /// Presents a card with cancel/confirm and registers callbacks for user actions
    private func showConfirmationCard() {
        confirmationCardVC = AddPhotoConfirmationViewController()
        confirmationCardVC!.onCancel = { [weak self] in self?.stop() }
        confirmationCardVC!.onConfirm = { [weak self] in self?.onPhotoLocationConfirmed() }
        canvasContainer.installCard(
            cardViewController: confirmationCardVC!,
            inView: canvasContainer.controls,
            cardConfig: CardConfiguration(showSafeAreaBlur: true)
        )
        confirmationCardVC!.showCard(animated: true)
    }

    private func showPanAndZoomIndicatorView() {
        panAndZoomIndicatorView = PanAndZoomIndicatorView()
        canvasContainer.controls.addSubview(panAndZoomIndicatorView!)
        panAndZoomIndicatorView!.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.bottom.equalTo(confirmationCardVC!.view.snp.top).offset(-12)
        }
    }

    /// Handle the photo location confirmation - potentially create the pin and close the flow
    private func onPhotoLocationConfirmed() {
        if let selectedPin = pinsHandler?.selectedPin {
            lastPhotoPinId = selectedPin.id
            // TODO: 44 add photo to collaboration
//            print("selected existing pin: \(selectedPin)")
        } else {
            // new position for pin
            // TODO: 44 here
//            let geometry = FirebaseGeometry(
//                id: UUID().uuidString.lowercased(),
//                // TODO: 44 need to have canvasId here, should come from current canvas id
//                canvasId: "a",
//                coordinates: canvasContainer.annotationsMapView.cameraState.center
//            )
//            lastPhotoPinId = geometry.id
//            do {
//                try Database.database().reference().child("geometryData/geometries").child(geometry.id)
//                    .setValue(from: geometry) { error in
//                        if let error = error {
//                            print("error creating geometry: \(error)")
//                        }
//                    }
//            } catch {
//                print("error saving geometry snapshot: \(error)")
//            }
        }
        stop()
    }
}

/// CanvasViewControllerDelegate
extension PhotoFlowController: CanvasViewControllerDelegate {
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
                    UIApplication.shared.open(settingsUrl)
                }
            })
        }
        return alertController
    }
}
