import AVFoundation
import Kingfisher
import OSLog
import PhotosUI
import Turf
import UIKit

/// Manages the flow of taking photo, adding details like tags and description and assigning the location on the canvas
class AddPhotoFlowController {
    unowned let model: ProjectModel
    unowned let imageCaches: ImageCaches
    unowned let canvasContainer: CanvasContainerViewController

    var onStop: (() -> Void)?
    var cameraVC: CameraViewController?
    var detailsVC: PhotoDetailsViewController?
    var pinsDisplay: AddPhotoPinsDisplay?
    var topViewController: AddPhotoTopViewController?
    var confirmationCardVC: AddPhotoConfirmationViewController?
    var photosPreviewCardVC: PhotosPreviewViewController?
    var panAndZoomIndicatorView: PanAndZoomIndicatorView?

    /// id of registered delegate
    var canvasDelegateId: UUID?

    /// selected photos to add
    let photosToAddViewModel: PhotosToAddViewModel
    /// tags from the details step
    var tagsViewModel: TagsViewModel
    /// description from the details step
    var photoDescription: String = ""
    /// location for the photo, optional as nil means that a new photoMarker should be added at the center of the current canvas
    var geometryId: String?

    /// When set to `true` the photo flow will exclude photo placement on the canvas and will use the provided geometryId
    var skipPhotoLocationSelection: Bool = false

    ///
    /// - Parameters:
    ///     - model: - the project model
    ///     - images: - access to images
    ///     - canvas: - the flow will operate on this canvas
    init(model: ProjectModel, imageCaches: ImageCaches, canvasContainer: CanvasContainerViewController) {
        self.model = model
        self.imageCaches = imageCaches
        self.canvasContainer = canvasContainer
        photosToAddViewModel = PhotosToAddViewModel(projectId: model.projectId, imageCaches: imageCaches)
        tagsViewModel = TagsViewModel(model: model)
        photosToAddViewModel.addDelegate(self)
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
        photosToAddViewModel.clear(removeFromCache: removeCurrentPhotosToAddFromCache)
        onStop?()
    }

    /// Restart the flow from the camera screen, cleaning all the collected data
    private func restart(removeCurrentPhotosToAddFromCache: Bool) {
        // clear the gathered data
        photosToAddViewModel.clear(removeFromCache: removeCurrentPhotosToAddFromCache)
        tagsViewModel = TagsViewModel(model: model)
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
        let vc = CameraViewController(photosViewModel: photosToAddViewModel)
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
        vc.onPhotoThumbnail = { [weak self] in
            self?.showPhotosReviewFromCameraScreen()
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

                if !UserDefaults.multiPhotoSessionEnabled {
                    // clear when not multi-photo session
                    self.photosToAddViewModel.clear(removeFromCache: true)
                }
                self.photosToAddViewModel.add(photoToAdd)

                if !UserDefaults.multiPhotoSessionEnabled {
                    self.nextStepAfterCamera()
                }
                completion(.success(()))
            }
    }

    private func selectPhotosFromCameraRoll(fromVC vc: UIViewController) {
        var pickerConfiguration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        // in multi-photo session preselect the photos that were already picked (in this session)
        pickerConfiguration.preselectedAssetIdentifiers = UserDefaults.multiPhotoSessionEnabled
            ? photosToAddViewModel.photos.compactMap(\.assetIdentifier)
            : []
        pickerConfiguration.selectionLimit = UserDefaults.multiPhotoSessionEnabled ? 0 : 1
        pickerConfiguration.filter = .images
        let picker = PHPickerViewController(configuration: pickerConfiguration)
        picker.overrideUserInterfaceStyle = .dark
        picker.delegate = self
        vc.present(picker, animated: true)
    }

    private func showPhotosReviewFromCameraScreen() {
        guard let cameraVC = cameraVC else { return }
        let vc = PhotosReviewViewController(imageCaches: imageCaches, photosViewModel: photosToAddViewModel)
        vc.onDone = { [weak vc] in
            guard let vc = vc else { return }
            vc.dismiss(animated: true)
        }
        vc.modalPresentationStyle = .fullScreen
        cameraVC.present(vc, animated: true)
    }

    private func showPhotosReviewFromDetailsScreen(interactivePresentation: UIPercentDrivenInteractiveTransition?) {
        guard let detailsVC = detailsVC else { return }
        let vc = PhotosReviewViewController(imageCaches: imageCaches, photosViewModel: photosToAddViewModel)
        vc.onDone = { [weak self, weak vc] in
            guard let self = self, let vc = vc else { return }
            if let detailsVC = self.detailsVC {
                // when hiding the photos review make sure that image gallery in details screen
                // shows the same page as the last viewed on photos review
                detailsVC.headerVC.galleryVC.setCurrentPage(vc.currentPage)
            }
            vc.dismiss(animated: true)
        }

        let galleryVC = detailsVC.headerVC.galleryVC!
        vc.currentPage = galleryVC.currentPage
        let transitioningDelegate = PhotosReviewTransitioningDelegate(
            fromGallery: galleryVC,
            toPhotosReview: vc,
            interactivePresentation: interactivePresentation
        )
        vc.photosReviewTransitioningDelegate = transitioningDelegate
        vc.transitioningDelegate = transitioningDelegate
        vc.modalPresentationStyle = .custom
        detailsVC.present(vc, animated: true)
    }

    private func nextStepAfterCamera() {
        if UserDefaults.annotationEnabled {
            selectPhotoDetails()
        } else if skipPhotoLocationSelection {
            // if we skip photo location and annotations then finalize the flow now
            finalizeFromCameraScreen()
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
        let vc = PhotoDetailsViewController(
            imageCaches: imageCaches,
            photosViewModel: photosToAddViewModel,
            tagsViewModel: tagsViewModel,
            initialDescription: photoDescription
        )
        if skipPhotoLocationSelection {
            vc.nextButtonLabel = String(localized: "Done")
            vc.nextButtonImage = nil
        }
        vc.onPhotoSelected = { [weak self] interactivePresentation in
            guard let self = self else { return }
            self.showPhotosReviewFromDetailsScreen(interactivePresentation: interactivePresentation)
        }
        vc.onBack = { [weak self] in
            guard let self = self, let detailsVC = self.detailsVC else { return }
            self.photoDescription = detailsVC.photoDescription
            detailsVC.navigationController?.popViewController(animated: true)
        }
        vc.onNext = { [weak self] in
            guard let self = self, let detailsVC = self.detailsVC else { return }
            self.photoDescription = detailsVC.photoDescription
            if self.skipPhotoLocationSelection {
                self.finalizeFromDetailsScreen()
            } else {
                self.canvasContainer.dismiss(animated: true)
                self.selectPhotoLocation()
            }
        }
        detailsVC = vc
        return vc
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

    /// Store the photo(s) and stop the flow
    /// Invoked from the camera screen when `skipPhotoLocationSelection` is `true` and `annotationEnabled` is `false`
    private func finalizeFromCameraScreen() {
        guard let cameraVC = cameraVC else { return }

        finalize(
            withProgressInView: cameraVC.view,
            cleanup: {},
            onSuccess: {
                self.canvasContainer.dismiss(animated: true)
                self.stop(removeCurrentPhotosToAddFromCache: false)
            }
        )
    }

    /// Store the photo(s) and stop the flow
    /// Invoked from the details screen when `skipPhotoLocationSelection` is `true`
    private func finalizeFromDetailsScreen() {
        guard let detailsVC = detailsVC else { return }

        detailsVC.nextButton.configuration?.showsActivityIndicator = true

        finalize(
            withProgressInView: detailsVC.view,
            cleanup: {
                detailsVC.nextButton.configuration?.showsActivityIndicator = false
            },
            onSuccess: {
                self.canvasContainer.dismiss(animated: true)
                self.stop(removeCurrentPhotosToAddFromCache: false)
            }
        )
    }

    /// Store the photo location, save all the data and stop the flow (andContinue == false) or restart with the camera screen
    /// Invoked from the confirmation card in the photo location selection
    private func finalizeFromConfirmationCard(andContinue restartFlow: Bool) {
        guard let confirmationCardVC = confirmationCardVC else { return }

        confirmationCardVC
            .setInactiveWithActivityIndicator(on: restartFlow
                ? confirmationCardVC.continueButton
                : confirmationCardVC.doneButton)

        geometryId = pinsDisplay?.selectedPin?.id

        finalize(
            withProgressInView: canvasContainer.view,
            cleanup: {
                confirmationCardVC.setActive()
            },
            onSuccess: {
                self.dismissPhotoLocationSelectionUI()
                restartFlow
                    ? self.restart(removeCurrentPhotosToAddFromCache: false)
                    : self.stop(removeCurrentPhotosToAddFromCache: false)
            }
        )
    }

    /// Add progress view to given `progressHostView` and stores the photo data.
    /// Runs the `cleanup` callback once the photo storage completes (whether successfull or not)
    /// Runs the `onSuccess` callback when storing data succeeded
    /// Both callbacks are dispatched on the main queue
    private func finalize(
        withProgressInView progressHostView: UIView,
        cleanup: @escaping () -> Void,
        onSuccess: @escaping () -> Void
    ) {
        // show activity view (a spinner) that covers the screen disabling any user interactions
        let activityView = UIActivityIndicatorView(style: .large)
        activityView.backgroundColor = .black.withAlphaComponent(0.2)
        progressHostView.addSubview(activityView)
        activityView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        activityView.startAnimating()

        Task {
            do {
                // hide the spinner when data store call is finished
                defer {
                    DispatchQueue.main.async {
                        activityView.removeFromSuperview()
                        cleanup()
                    }
                }
                try await _storeData()
                DispatchQueue.main.async {
                    onSuccess()
                }
            } catch {
                Logger.model.error("finalize error: \(error.localizedDescription, privacy: .public)")
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
                photosToAddViewModel.photos,
                tags: tagsViewModel.selectedTags,
                description: photoDescription,
                toCollaborationForGeometryId: geometryId
            ))
            UserDefaults.lastPhotoPinId = geometryId
        } else {
            let geometryId = generateRealmId()
            try await model.runCommands(model.addPhotos(
                photosToAddViewModel.photos,
                tags: tagsViewModel.selectedTags,
                description: photoDescription,
                at: canvasContainer.annotationsMapView.cameraState.center,
                in: canvasContainer.pdfCanvasViewController.pdfCanvas,
                geometryId: geometryId
            ))
            UserDefaults.lastPhotoPinId = geometryId
        }
        UserDefaults.addRecentTagIds(tagsViewModel.selectedTags.map(\.id), forProjectId: model.projectId)
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
        pinsDisplay = AddPhotoPinsDisplay(
            canvasContainer: canvasContainer,
            image: photosToAddViewModel.photos.first!.thumbnail
        )
        pinsDisplay?.onSelectedPinChange = { [weak self] pinPoint in
            if let geometryId = pinPoint?.id {
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
            self?.finalizeFromConfirmationCard(andContinue: false)
        }
        confirmationCardVC!.onContinue = { [weak self] in
            self?.finalizeFromConfirmationCard(andContinue: true)
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
            let updatePhotosError = await photosToAddViewModel.update(withPickerResults: results)
            DispatchQueue.main.async {
                activityView.removeFromSuperview()
                picker.dismiss(animated: true)
                if let updatePhotosError = updatePhotosError, let cameraVC = self.cameraVC {
                    let errorMessage: String
                    if results.count == 1 {
                        errorMessage = "The photo couldn't be added. " + updatePhotosError.localizedDescription
                    } else {
                        errorMessage = "Some of the photos couldn't be added. " + updatePhotosError.localizedDescription
                    }
                    self.showError(withMessage: errorMessage, in: cameraVC)
                }
                if updatePhotosError == nil, !UserDefaults.multiPhotoSessionEnabled {
                    self.nextStepAfterCamera()
                }
            }
        }
    }
}

/// PhotosToAddViewModel delegate
extension AddPhotoFlowController: PhotosToAddViewModelDelegate {
    /// When the last photo is removed automatically hide the photos review screen and get back to camera screen (if in details)
    func photoRemoved(atIndex _: Int) {
        if photosToAddViewModel.photos.isEmpty, let cameraVC = cameraVC {
            if let detailsVC = detailsVC {
                /// Hack: animated presentation of photos review leaves the presenting vc with alpha = 0, restore here manually
                /// as there won't be custom animated transitioning running for this case because there are no images to
                /// transition between
                cameraVC.navigationController?.view.alpha = 1.0
                detailsVC.dismiss(animated: true) {
                    cameraVC.navigationController?.popToViewController(cameraVC, animated: true)
                }
            } else {
                cameraVC.dismiss(animated: true)
            }
        }
    }
}
