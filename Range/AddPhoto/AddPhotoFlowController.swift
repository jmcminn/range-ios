import AVFoundation
import Kingfisher
import OSLog
import PhotosUI
import Turf
import UIKit

/// Information about the photo to add
struct PhotoToAdd {
    /// UUID
    var uploadId: String
    /// when the photo was taken
    var timestamp: TimeInterval
    /// key for images.cameraCache, matches the storage keys, so composed of projectId and uploadId
    var cacheKey: String
    /// small 100x100 image (with proper aspect ratio)
    var thumbnail: UIImage
    /// to layout before fetching from cache
    var height2Width: Double
}

/// Manages the flow of taking photo, adding details like tags and description and assigning the location on the canvas
class AddPhotoFlowController {
    unowned let model: ProjectModel
    unowned let imageCaches: ImageCaches
    unowned let canvasContainer: CanvasContainerViewController

    var onStop: (() -> Void)?
    var cameraVC: CameraViewController?
    var pinsDisplay: AddPhotoPinsDisplay?
    var topViewController: AddPhotoTopViewController?
    var confirmationCardVC: AddPhotoConfirmationViewController?
    var photosPreviewCardVC: PhotosPreviewViewController?
    var panAndZoomIndicatorView: PanAndZoomIndicatorView?

    /// id of registered delegate
    var canvasDelegateId: UUID?

    /// selected photos to add
    var photosToAdd: [PhotoToAdd] = []
    /// photo from the camera step
//    var image: UIImage!
    /// source data for the `image`
//    var imageData: Data!
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
    init(model: ProjectModel, imageCaches: ImageCaches, canvasContainer: CanvasContainerViewController) {
        self.model = model
        self.imageCaches = imageCaches
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

    func stop(removeCurrentPhotosToAddFromCache: Bool) {
        clearPhotosToAdd(removeFromCache: removeCurrentPhotosToAddFromCache)
        onStop?()
    }

    /// Restart the flow from the camera screen, cleaning all the collected data
    private func restart(removeCurrentPhotosToAddFromCache: Bool) {
        // clear the gathered data
        clearPhotosToAdd(removeFromCache: removeCurrentPhotosToAddFromCache)
        tags = []
        photoDescription = ""
        geometryId = nil

        showCamera()
    }

    /// Cleanup the current photosToAdd
    /// If the photos were used for uploads they should remain in cache, otherwise should be removed
    private func clearPhotosToAdd(removeFromCache: Bool) {
        // remove the photos from local cache if we don't need them
        if removeFromCache {
            photosToAdd.forEach {
                imageCaches.localPhotosCache.removeImage(forKey: $0.cacheKey)
            }
            imageCaches.localPhotosCache.clearMemoryCache()
        }
        photosToAdd = []
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
        vc.updateWithPhotosToAdd(photosToAdd)
        vc.onClose = { [weak self, weak vc] in
            vc?.dismiss(animated: true)
            self?.stop(removeCurrentPhotosToAddFromCache: true)
        }
        vc.onPhotoTaken = { [weak self] data, image, completion in
            self?.onPhotoTaken(data: data, image: image, completion: completion)
        }
        vc.onNext = { [weak self] in
            self?.nextStepAfterCamera()
        }
        vc.onCameraRollSelect = { [weak self, weak vc] in
            guard let self = self, let vc = vc else { return }
            self.selectPhotosFromCameraRoll(fromVC: vc)
        }
        cameraVC = vc
        return vc
    }

    /// Store the image and proceed to the photo details selection step
    private func onPhotoTaken(
        data: Data,
        image: UIImage,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let uploadId = generateRealmId()
        let cacheKey = uploadKey(projectId: model.projectId, uploadId: uploadId)

        let photoToAdd = PhotoToAdd(
            uploadId: uploadId,
            timestamp: Date.now.timeIntervalSince1970,
            cacheKey: cacheKey,
            thumbnail: image.imageResized(toFill: 100),
            height2Width: image.size.height / image.size.width
        )

        // store the image in local cache
        imageCaches.localPhotosCache
            .storeToDisk(data, forKey: cacheKey, callbackQueue: .mainAsync) { [weak self] result in
                guard let self = self else { return }
                if case let .failure(error) = result.diskCacheResult {
                    completion(.failure(error))
                    return
                }

                if UserDefaults.multiPhotoSessionEnabled {
                    self.photosToAdd.append(photoToAdd)
                } else {
                    self.clearPhotosToAdd(removeFromCache: true)
                    self.photosToAdd = [photoToAdd]
                }
                self.cameraVC?.updateWithPhotosToAdd(self.photosToAdd)
                if !UserDefaults.multiPhotoSessionEnabled {
                    self.nextStepAfterCamera()
                }
                completion(.success(()))
            }
    }

    private func selectPhotosFromCameraRoll(fromVC vc: UIViewController) {
        var pickerConfiguration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        pickerConfiguration.selectionLimit = UserDefaults.multiPhotoSessionEnabled ? 0 : 1
        pickerConfiguration.filter = .images
        let picker = PHPickerViewController(configuration: pickerConfiguration)
        picker.overrideUserInterfaceStyle = .dark
        picker.delegate = self
        vc.present(picker, animated: true)
    }

    private func nextStepAfterCamera() {
        if UserDefaults.annotationEnabled {
            selectPhotoDetails()
        } else {
            // go straight to photo location
            canvasContainer.dismiss(animated: true)
            selectPhotoLocation()
        }
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
            imageCaches: imageCaches,
            photosToAdd: photosToAdd,
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
        if UserDefaults.annotationEnabled {
            navC.viewControllers = [createCameraViewController(), createPhotoDetailsViewController()]
        } else {
            navC.viewControllers = [createCameraViewController()]
        }
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

        geometryId = pinsDisplay?.selectedPin?.id
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
                    restartFlow
                        ? self.restart(removeCurrentPhotosToAddFromCache: false)
                        : self.stop(removeCurrentPhotosToAddFromCache: false)
                }
            } catch {
                Logger.model.error("photo location data store error: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    self.showError(withMessage: error.localizedDescription, in: self.canvasContainer)
                }
            }
        }
    }

    private func showError(withMessage message: String, in vc: UIViewController) {
        let alertController = UIAlertController(
            title: "Add photo error",
            message: message,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        vc.present(alertController, animated: true)
    }

    /// Async function to store the new photo(s) data in the realm DB
    @MainActor
    private func _storeData() async throws {
        if let geometryId = geometryId {
            try await model.runCommands(model.addPhotos(
                photosToAdd,
                tags: tags,
                description: photoDescription,
                toCollaborationForGeometryId: geometryId
            ))
            UserDefaults.lastPhotoPinId = geometryId
        } else {
            let geometryId = generateRealmId()
            try await model.runCommands(model.addPhotos(
                photosToAdd,
                tags: tags,
                description: photoDescription,
                at: canvasContainer.annotationsMapView.cameraState.center,
                in: canvasContainer.pdfCanvasViewController.pdfCanvas,
                geometryId: geometryId
            ))
            UserDefaults.lastPhotoPinId = geometryId
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
        pinsDisplay?.stop()
        panAndZoomIndicatorView?.removeFromSuperview()
        pinsDisplay = nil
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
        pinsDisplay = AddPhotoPinsDisplay(model: model,
                                          canvasContainer: canvasContainer,
                                          image: photosToAdd.first!.thumbnail)
        pinsDisplay?.onSelectedPinChange = { [weak self] geometryId in
            if let geometryId = geometryId {
                self?.showPhotosPreview(forGeometry: geometryId, animated: true)
            } else {
                self?.hidePhotosPreview(animated: true)
            }
        }
        pinsDisplay?.start()
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
            imageCaches: imageCaches,
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

/// Delegate for selecting photos from the camera roll
extension AddPhotoFlowController: PHPickerViewControllerDelegate {
    /// Errors for camera roll photos processing
    enum CameraRollError: Error, Equatable {
        case unsupportedType
        case thumbnailGenerationFailed
    }

    /// Get image data for given photo picker result and return PhotoToAdd
    /// Implementation based on: https://itnext.io/the-right-way-to-use-phpicker-and-retrieve-exif-data-without-requesting-library-permissions-in-336c13f87e3f
    private func getPhotoToAdd(forPickerResult result: PHPickerResult) async throws -> PhotoToAdd {
        let itemProvider: NSItemProvider = result.itemProvider
        guard itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
            throw CameraRollError.unsupportedType
        }
        let data = try await itemProvider._asyncLoadDataRepresentation(forTypeIdentifier: UTType.image.identifier)
        guard let resizedData = resizeImage(imageData: data, maxResolution: 100),
              let thumbnail = UIImage(data: resizedData)
        else {
            throw CameraRollError.thumbnailGenerationFailed
        }
        let uploadId = generateRealmId()
        let cacheKey = uploadKey(projectId: model.projectId, uploadId: uploadId)

        try await imageCaches.localPhotosCache._asyncStoreToDisk(data, forKey: cacheKey)

        return PhotoToAdd(
            uploadId: uploadId,
            timestamp: Date.now.timeIntervalSince1970,
            cacheKey: cacheKey,
            thumbnail: thumbnail,
            height2Width: thumbnail.size.height / thumbnail.size.width
        )
    }

    /// Converts picker results to PhotoToAdd using getPhotoToAdd(forPickerResult:).
    /// In case of errors collects them in a separate array and returns.
    private func getPhotosToAdd(forPickerResults results: [PHPickerResult]) async -> ([PhotoToAdd], [Error]) {
        var photos: [PhotoToAdd] = []
        var errors: [Error] = []
        for result in results {
            do {
                photos.append(try await getPhotoToAdd(forPickerResult: result))
            } catch {
                Logger.camera.error("getPhotoToAdd error: \(error.localizedDescription, privacy: .public)")
                errors.append(error)
            }
        }
        return (photos, errors)
    }

    /// Handling of photos picked from camera roll
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // show activity view (a spinner) that covers the screen disabling any user interactions
        let activityView = UIActivityIndicatorView(style: .large)
        activityView.backgroundColor = .black.withAlphaComponent(0.2)
        picker.view.addSubview(activityView)
        activityView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        activityView.startAnimating()

        Task {
            let (pickedPhotosToAdd, errors) = await getPhotosToAdd(forPickerResults: results)
            DispatchQueue.main.async {
                activityView.removeFromSuperview()
                picker.dismiss(animated: true)
                if errors.count > 0, let cameraVC = self.cameraVC {
                    let errorMessage: String
                    if results.count == 1 {
                        errorMessage = "The photo couldn't be added. " + (errors.first?.localizedDescription ?? "")
                    } else {
                        errorMessage = "Some of the photos couldn't be added. " + (errors.first?
                            .localizedDescription ?? "")
                    }
                    self.showError(withMessage: errorMessage, in: cameraVC)
                }
                if pickedPhotosToAdd.count > 0 {
                    if UserDefaults.multiPhotoSessionEnabled {
                        self.photosToAdd.append(contentsOf: pickedPhotosToAdd)
                    } else {
                        self.clearPhotosToAdd(removeFromCache: true)
                        self.photosToAdd = pickedPhotosToAdd
                    }
                    self.cameraVC?.updateWithPhotosToAdd(self.photosToAdd)
                    if !UserDefaults.multiPhotoSessionEnabled {
                        self.nextStepAfterCamera()
                    }
                }
            }
        }
    }
}
