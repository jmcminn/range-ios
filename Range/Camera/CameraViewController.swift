import OSLog
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
    /// callback with photo data/UIImage and a completion that will resolve after the photo is stored locally
    var onPhotoTaken: ((Data, UIImage, @escaping (Result<Void, Error>) -> Void) -> Void)?
    var onNext: (() -> Void)?
    var modalCardDisplayController: ModalCardDisplayController?
    private let cameraService = CameraService()
    let cameraViewModel: CameraViewModel

    init() {
        cameraViewModel = CameraViewModel(cameraService: cameraService)
        super.init(rootView: CameraView(model: cameraViewModel))

        cameraViewModel.closeAction = { [weak self] in
            self?.onClose?()
        }
        cameraViewModel.takePhotoAction = { [weak self] in
            self?.takePhotoAction()
        }
        cameraViewModel.nextAction = { [weak self] in
            self?.onNext?()
        }
    }

    func updateWithPhotosToAdd(_ photosToAdd: [PhotoToAdd]) {
        cameraViewModel.numberOfPhotos = photosToAdd.count
        cameraViewModel.photoThumbnail = photosToAdd.first?.thumbnail
    }

    private func takePhotoAction() {
        guard let onPhotoTaken = onPhotoTaken else { return }
        cameraService.capturePhoto { [weak self] data in
            guard let self = self else { return }
            if let data = data, let image = UIImage(data: data) {
                onPhotoTaken(data, image) { result in
                    if case let .failure(error) = result {
                        Logger.camera
                            .error("Error while saving the photo: \(error.localizedDescription, privacy: .public)")
                        self.showCapturePhotoErrorAlert(taking: false)
                    }
                }
            } else {
                self.showCapturePhotoErrorAlert()
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

    /// show error while taking (true) or saving (false) the photo
    private func showCapturePhotoErrorAlert(taking: Bool = true) {
        let alertController = UIAlertController(
            title: "Camera Error",
            message: taking ? "Error while taking the photo, please try again." :
                "Error while saving the photo, please try again.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
        present(alertController, animated: true)
    }

    // configure the CameraService when the view loads
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.isNavigationBarHidden = true
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
