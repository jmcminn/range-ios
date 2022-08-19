import AVFoundation
import OSLog
import Turf
import UIKit

/// Manages the flow of taking photo, adding details like tags and description and assigning the location on the canvas
class AddPhotoFlowController {
    unowned let model: ProjectModel
    unowned let images: Images
    unowned let canvasContainer: CanvasContainerViewController

    var onStop: (() -> Void)?
    var pinsHandler: AddPhotoPinsHandler?
    var topViewController: AddPhotoTopViewController?
    var confirmationCardVC: AddPhotoConfirmationViewController?
    var photosPreviewCardVC: PhotosPreviewViewController?
    var panAndZoomIndicatorView: PanAndZoomIndicatorView?

    /// id of registered delegate
    var canvasDelegateId: UUID?

    /// photo from the camera step
    var image: UIImage!
    /// source data for the `image`
    var imageData: Data!
    /// tags from the details step
    var tags: [TagViewModel] = []
    /// description from the details step
    var photoDescription: String = ""
    /// location for the photo, optional as nil means that a new photoMarker should be added at the center of the current canvas
    var geometryId: String?

    ///
    /// - Parameters:
    ///     - model: - the project model
    ///     - images: - access to images
    ///     - canvas: - the flow will operate on this canvas
    init(model: ProjectModel, images: Images, canvasContainer: CanvasContainerViewController) {
        self.model = model
        self.images = images
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
        onStop?()
    }

    /// Restart the flow from the camera screen, cleaning all the collected data
    private func restart() {
        // clear the gathered data
        image = nil
        imageData = nil
        tags = []
        photoDescription = ""
        geometryId = nil

        showCamera()
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

    /// Present camera view in a new navigation controller presented modally on top of the canvas container
    private func showCamera() {
        let navC = UINavigationController(rootViewController: createCameraViewController())
        navC.modalPresentationStyle = .fullScreen
        canvasContainer.present(navC, animated: true)
    }

    /// Creates the `CameraViewController` and installs the flow callbacks
    private func createCameraViewController() -> CameraViewController {
        let vc = CameraViewController()
        vc.onClose = { [weak self, weak vc] in
            vc?.dismiss(animated: true)
            self?.stop()
        }
        vc.onPhotoTaken = { [weak self] data, image in
            self?.onPhotoTaken(data: data, image: image)
        }
        return vc
    }

    /// Store the image and proceed to the photo details selection step
    private func onPhotoTaken(data: Data, image: UIImage) {
        imageData = data
        self.image = image
        selectPhotoDetails()
    }

    /// push photo details view controller onto the navigation controller for the camera screen
    private func selectPhotoDetails() {
        (canvasContainer.presentedViewController as? UINavigationController)?
            .pushViewController(createPhotoDetailsViewController(), animated: true)
    }

    /// Creates the `PhotoDetailsViewController` and installs the flow callbacks
    private func createPhotoDetailsViewController() -> PhotoDetailsViewController {
        let detailsVC = PhotoDetailsViewController(
            model: model,
            image: image,
            initialSelectedTags: tags,
            initialDescription: photoDescription
        )
        detailsVC.onBack = { [weak detailsVC] in
            detailsVC?.navigationController?.popViewController(animated: true)
        }
        detailsVC.onNext = { [weak self] tags, photoDescription in
            self?.onPhotoDetailsSelected(tags: tags, photoDescription: photoDescription)
        }
        return detailsVC
    }

    /// Store the photo details and proceed to the location selection step
    private func onPhotoDetailsSelected(tags: [TagViewModel], photoDescription: String) {
        self.tags = tags
        self.photoDescription = photoDescription
        canvasContainer.dismiss(animated: true)
        selectPhotoLocation()
    }

    /// Adapt the UI for the location selection
    private func selectPhotoLocation() {
        canvasDelegateId = canvasContainer.pdfCanvasViewController.addDelegate(self)
        showTopViewController()
        showConfirmationCard()
        showPanAndZoomIndicatorView()
        showPins()
    }

    /// go back from photo location selection to photo details
    private func onPhotoLocationBack() {
        dismissPhotoLocationSelectionUI()
        // setup a navigation controller with camera and photo details, so user can go back
        // from the details to camera screen
        let navC = UINavigationController()
        navC.viewControllers = [createCameraViewController(), createPhotoDetailsViewController()]
        navC.modalPresentationStyle = .fullScreen
        canvasContainer.present(navC, animated: true)
    }

    /// Store the photo location, save all the data and stop the flow (andContinue == false) or restart with the camera screen
    private func addPhoto(andContinue restartFlow: Bool) {
        guard let confirmationCardVC = confirmationCardVC else {
            return
        }

        // show activity view (a spinner) that covers the screen disabling any user interactions
        let activityView = UIActivityIndicatorView(style: .large)
        activityView.backgroundColor = .black.withAlphaComponent(0.2)
        canvasContainer.view.addSubview(activityView)
        activityView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        activityView.startAnimating()
        confirmationCardVC
            .setInactiveWithActivityIndicator(on: restartFlow
                ? confirmationCardVC.continueButton
                : confirmationCardVC.doneButton)

        geometryId = pinsHandler?.selectedPin?.id
        Task {
            do {
                // hide the spinner when data store call is finished
                defer {
                    DispatchQueue.main.async {
                        activityView.removeFromSuperview()
                        confirmationCardVC.setActive()
                    }
                }
                try await _storeData()
                DispatchQueue.main.async {
                    self.dismissPhotoLocationSelectionUI()
                    restartFlow ? self.restart() : self.stop()
                }
            } catch {
                Logger.model.error("photo location data store error: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    self.showError(withMessage: error.localizedDescription)
                }
            }
        }
    }

    private func showError(withMessage message: String) {
        let alertController = UIAlertController(
            title: "Add photo error",
            message: message,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        canvasContainer.present(alertController, animated: true)
    }

    /// Async function to store the new photo data in the realm DB
    @MainActor
    private func _storeData() async throws {
        if let geometryId = geometryId {
            try await model.runCommands(model.addPhoto(
                imageData,
                tags: tags,
                description: photoDescription,
                toCollaborationForGeometryId: geometryId
            ))
            lastPhotoPinId = geometryId
        } else {
            let geometryId = generateRealmId()
            try await model.runCommands(model.addPhoto(
                imageData,
                tags: tags,
                description: photoDescription,
                at: canvasContainer.annotationsMapView.cameraState.center,
                in: canvasContainer.pdfCanvasViewController.pdfCanvas,
                geometryId: geometryId
            ))
            lastPhotoPinId = geometryId
        }
    }
}

// MARK: - photo location selection UI adaptation

extension AddPhotoFlowController {
    /// remove the photo location selection views/handlers
    private func dismissPhotoLocationSelectionUI() {
        if let canvasDelegateId = canvasDelegateId {
            canvasContainer.pdfCanvasViewController.removeDelegate(id: canvasDelegateId)
        }
        if let photosPreviewCardVC = photosPreviewCardVC {
            photosPreviewCardVC.hideCard(animated: true) {
                self.canvasContainer.removeCard(cardViewController: photosPreviewCardVC)
            }
        }
        if let confirmationCardVC = confirmationCardVC {
            confirmationCardVC.hideCard(animated: true) {
                self.canvasContainer.removeCard(cardViewController: confirmationCardVC)
            }
        }
        hideTopViewController()
        pinsHandler?.stop()
        panAndZoomIndicatorView?.removeFromSuperview()
        pinsHandler = nil
    }

    /// shows the view controller covering the top of of the screen
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

    /// Starts the pin handler that adds the pins to the canvas and allows for the selection
    private func showPins() {
        pinsHandler = AddPhotoPinsHandler(model: model,
                                          canvasContainer: canvasContainer,
                                          image: image)
        pinsHandler?.onSelectedPinChange = { [weak self] geometryId in
            if let geometryId = geometryId {
                self?.showPhotosPreview(forGeometry: geometryId, animated: true)
            } else {
                self?.hidePhotosPreview(animated: true)
            }
        }
        pinsHandler?.start()
    }

    /// Presents a card with cancel/confirm and registers callbacks for user actions
    private func showConfirmationCard() {
        confirmationCardVC = AddPhotoConfirmationViewController()
        confirmationCardVC!.onCancel = { [weak self] in
            self?.onPhotoLocationBack()
        }
        confirmationCardVC!.onDone = { [weak self] in
            self?.addPhoto(andContinue: false)
        }
        confirmationCardVC!.onContinue = { [weak self] in
            self?.addPhoto(andContinue: true)
        }
        canvasContainer.installCard(
            cardViewController: confirmationCardVC!,
            inView: canvasContainer.controls,
            cardConfig: CardConfiguration(interactive: false, showSafeAreaBlur: true)
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

    /// shows the photos for given geometryId
    private func showPhotosPreview(forGeometry geometryId: String, animated: Bool) {
        guard let confirmationCardVC = confirmationCardVC else { return }
        let photosPreviewVC = PhotosPreviewViewController(
            model: model,
            images: images,
            geometryId: geometryId,
            confirmationVC: confirmationCardVC
        )
        canvasContainer.installCard(
            cardViewController: photosPreviewVC,
            inView: canvasContainer.controls,
            cardConfig: CardConfiguration(initialCardPosition: .medium, interactive: false)
        )
        // move photos preview below confirmation
        canvasContainer.controls.insertSubview(photosPreviewVC.view, belowSubview: confirmationCardVC.view)

        // check if already showing, if so then ignore animated and replace instantly
        if photosPreviewCardVC != nil {
            hidePhotosPreview(animated: false)
            photosPreviewVC.showCard(animated: false)
        } else {
            photosPreviewVC.showCard(animated: animated)
        }
        photosPreviewCardVC = photosPreviewVC
        confirmationCardVC.showDarkBorder = true
        if let panAndZoomIndicatorView = panAndZoomIndicatorView {
            // anchor to photos preview
            panAndZoomIndicatorView.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(12)
                make.bottom.equalTo(photosPreviewVC.view.snp.top).offset(-12)
            }
        }
    }

    /// Hide the currently shown collaboration window
    private func hidePhotosPreview(animated: Bool) {
        if let panAndZoomIndicatorView = panAndZoomIndicatorView,
           let confirmationCardVC = confirmationCardVC
        {
            // anchor back to confirmation
            panAndZoomIndicatorView.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(12)
                make.bottom.equalTo(confirmationCardVC.view.snp.top).offset(-12)
            }
        }
        confirmationCardVC?.showDarkBorder = false
        if let photosPreviewCardVC = photosPreviewCardVC {
            photosPreviewCardVC.hideCard(animated: animated) {
                self.canvasContainer.removeCard(cardViewController: photosPreviewCardVC)
            }
            self.photosPreviewCardVC = nil
        }
    }
}

/// CanvasViewControllerDelegate
extension AddPhotoFlowController: CanvasViewControllerDelegate {
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
private extension AddPhotoFlowController {
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
