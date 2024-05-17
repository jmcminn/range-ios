import CoreMotion
import OSLog
import SwiftUI
import UIKit

// A UIHostingController defines a UIViewController (from UIKit as opposed to SwiftUI) that nonetheless manages a
// SwiftUI view hierarchy

/// A UIViewController whose view is a CameraView
/// It also owns and manages a CameraService and uses it to actually take photos
class CameraViewController: UIHostingController<CameraView> {
    unowned let photosViewModel: PhotosToAddViewModel
    // for analytics
    private let projectType: ProjectSummary.ProjectType
    var onClose: (() -> Void)?
    /// callback with photo data/UIImage and a completion that will resolve after the photo is stored locally
    var onPhotoTaken: ((Data, UIImage, @escaping (Result<Void, Error>) -> Void) -> Void)?
    var onCameraRollSelect: (() -> Void)?
    var onPhotoThumbnail: (() -> Void)?
    var onNext: (() -> Void)?
    private let cameraService = CameraService()
    let cameraViewModel: CameraViewModel

    /// To recognize device orientation change when Portrait Orientation Lock is On we need to observe the device motion
    /// instead of relying on UIDevice.current.orientation value and UIDevice.orientationDidChangeNotification, as UIDevice
    /// reports portrait when the Lock is on, no matter what's the actual real device orientation
    let motionManager = CMMotionManager()
    var deviceOrientation: UIDeviceOrientation = .portrait { didSet {
        // calculate new angle for ui elements when the device is rotated
        switch deviceOrientation {
        case .portraitUpsideDown:
            cameraViewModel.uiAngle = .degrees(180)
        case .landscapeLeft:
            cameraViewModel.uiAngle = .degrees(90)
        case .landscapeRight:
            cameraViewModel.uiAngle = .degrees(-90)
        default:
            cameraViewModel.uiAngle = .degrees(0)
        }
    }}

    init(
        userPreferences: UserPreferences,
        photosViewModel: PhotosToAddViewModel,
        projectType: ProjectSummary.ProjectType
    ) {
        self.photosViewModel = photosViewModel
        self.projectType = projectType
        cameraViewModel = CameraViewModel(cameraService: cameraService, userPreferences: userPreferences)
        super.init(rootView: CameraView(model: cameraViewModel))

        photosViewModel.addDelegate(self)
        cameraViewModel.closeAction = { [weak self] in
            self?.onClose?()
        }
        cameraViewModel.takePhotoAction = { [weak self] in
            self?.takePhotoAction()
        }
        cameraViewModel.nextAction = { [weak self] in
            self?.onNext?()
        }
        cameraViewModel.cameraRollSelectAction = { [weak self] in
            self?.onCameraRollSelect?()
        }
        cameraViewModel.photoThumbnailAction = { [weak self] in
            self?.onPhotoThumbnail?()
        }
    }

    private func takePhotoAction() {
        guard let onPhotoTaken = onPhotoTaken else { return }
        cameraService
            .capturePhoto(flashMode: cameraViewModel.flashMode,
                          deviceOrientation: deviceOrientation) { [weak self] data in
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

        motionManager.startDeviceMotionUpdates(to: OperationQueue()) { [weak self] data, _ in
            guard let self = self else { return }
            guard let gravity = data?.gravity else { return }
            let newDeviceOrientation: UIDeviceOrientation
            if abs(gravity.y) < abs(gravity.x) {
                newDeviceOrientation = gravity.x > 0 ? .landscapeRight : .landscapeLeft
            } else {
                newDeviceOrientation = gravity.y > 0 ? .portraitUpsideDown : .portrait
            }
            if self.deviceOrientation != newDeviceOrientation {
                DispatchQueue.main.async {
                    self.deviceOrientation = newDeviceOrientation
                }
            }
        }
    }

    // start the CameraService before the view appears
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraService.start()
        analytics?.screen(title: "camera", properties: ["projectType": projectType])
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

// Delegate for photos view model
extension CameraViewController: PhotosToAddViewModelDelegate {
    func photoAdded(atIndex _: Int) {
        updateCameraViewModelFromPhotosViewModel()
    }

    func photoRemoved(atIndex _: Int) {
        updateCameraViewModelFromPhotosViewModel()
    }

    private func updateCameraViewModelFromPhotosViewModel() {
        cameraViewModel.numberOfPhotos = photosViewModel.photos.count
        cameraViewModel.photoThumbnail = photosViewModel.photos.first?.thumbnail
    }
}
