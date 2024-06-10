import AVFoundation
import Kingfisher
import OSLog
import PhotosUI
import Realm
import RealmSwift
import Turf
import UIKit

/// Manages the flow of taking photo, adding details like tags and description and assigning the location on the canvas
class AddPhotoFlowController {
    unowned let model: ProjectModel
    unowned let localFiles: LocalFiles
    unowned let mediaCache: MediaCache
    unowned let userSettings: UserSettings
    let userPreferences: UserPreferences
    unowned let canvasContainer: CanvasContainerViewController

    private let controls: ProjectCanvasControls

    /// on Stop it returns the id of the geometry to which the photo(s) was added to (if not cancelled) and whether the
    /// collaboration was created (`true`) or existing one was used (`false`) and whether the collaboration should be edited after creation
    var onStop: ((String?, Bool?, Bool?) -> Void)?
    var cameraVC: CameraViewController?
    var detailsVC: PhotoDetailsViewController?
    var pinsDisplay: AddPhotoPinsDisplay?
    var confirmationCardVC: AddPhotoConfirmationViewController?
    var photosPreviewCardVC: PhotosPreviewViewController?
    var switchPinTypeCardVC: SwitchPinTypeCardViewController?

    /// id of registered delegate
    var canvasDelegateId: UUID?

    /// To observed changes in model.currentCanvas
    private var canvasObservation: NSKeyValueObservation?

    /// selected photos to add
    let photosToAddViewModel: PhotosToAddViewModel
    /// tags from the details step
    var tagsViewModel: TagsViewModel
    /// description from the details step
    var photoDescription: String = ""
    /// location for the photo, optional as nil means that a new photoMarker should be added at the center of the current canvas
    var geometryId: String?
    /// if the photo(s) added by this flow are versions of previous photo, they're linked using this id.
    /// Only used when adding photos to collaboration. Not used when creating a new collaboration (as photo versioning scope is collaboration and
    /// initial photos for collaboration cannot be versioned)
    var correlationId: String?
    /// pin to copy data from when in .copyPin mode
    var pinToCopy: Collaboration?
    /// whether to create photo or task collaboration
    var pinTypeOption: PinTypeOption = .createTask {
        didSet {
            pinsDisplay?.photoPinView?.pinType = pinTypeOption.pinType
            confirmationCardVC?.showNextButton = pinTypeOption == .copyPin
        }
    }

    /// if the photo flow finished with success (and was not cancelled) this stores the id of the geometry the photos were added to
    private var resultGeometryId: String?
    /// whether the photos were added to newly created collaboration (`true`) or to an existing one (`false`)
    private var newCollaborationCreated: Bool?
    /// should edit collaboration
    private var shouldEditCollaboration: Bool?

    /// When set to `true` the photo flow will start with the photo details screen (or whatever is the first screen after the camera screen)
    /// Setting this to `true` requires that there are some preconfigured photos to add
    var skipCameraScreen: Bool = false

    /// When set to `true` the photo details screen (annotation, tags, description) will not be shown.
    /// When set to `false` the photo details screen will always be shown
    /// When set to `nil` it will be shown if `UserDefaults.annotationEnabled` is `true`
    var skipDetailsScreen: Bool?
    private var showDetailsScreen: Bool {
        if let skipDetailsScreen { return !skipDetailsScreen }
        return userPreferences.annotationEnabled
    }

    /// Show the photos review when the details screen is shown initially (used by canvas snapshot flow to direct user to
    /// annotations initially)
    var autoShowPhotosReviewFromDetailsScreen: Bool = false

    /// When set to `true` the photo flow will exclude photo placement on the canvas and will use the provided geometryId
    var skipPhotoLocationSelection: Bool = false

    /// Whether the initial location should be automatically selected based on user location / last selected location
    var autoSelectInitialLocation: Bool = true

    /// Whether user can select multiple photos
    var allowMultiPhotoSelection: Bool = true

    ///
    /// - Parameters:
    ///     - model: - the project model
    ///     - images: - access to images
    ///     - canvas: - the flow will operate on this canvas
    init(
        model: ProjectModel,
        localFiles: LocalFiles,
        mediaCache: MediaCache,
        userSettings: UserSettings,
        userPreferences: UserPreferences,
        canvasContainer: CanvasContainerViewController
    ) {
        self.model = model
        self.localFiles = localFiles
        self.mediaCache = mediaCache
        self.userSettings = userSettings
        self.userPreferences = userPreferences
        self.canvasContainer = canvasContainer
        controls = ProjectCanvasControls(canvasContainer: canvasContainer)
        photosToAddViewModel = PhotosToAddViewModel(projectId: model.projectId, localFiles: localFiles)
        tagsViewModel = TagsViewModel(model: model, userPreferences: userPreferences)
        photosToAddViewModel.addDelegate(self)

        pinTypeOption = userPreferences.lastPinTypeOption ?? .createTask
    }

    /// Attempts to start the photo flow. Will callback the `onStarted`on the main queue with the result
    func start(onStarted: @escaping (Bool) -> Void) {
        if skipCameraScreen {
            nextStepAfterCamera()
            onStarted(true)
        } else {
            Task {
                let started = await checkPermissionsAndShowCamera()
                DispatchQueue.main.async {
                    onStarted(started)
                }
            }
        }
    }

    func stop(removeCurrentPhotosToAddFromCache: Bool) {
        controls.removeFromSuperview()
        photosToAddViewModel.clear(removeFromCache: removeCurrentPhotosToAddFromCache)
        onStop?(resultGeometryId, newCollaborationCreated, shouldEditCollaboration)
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
        // currentContext makes it present over the ProjectFlowController to correctly handle the
        // responder chain (so the ProjectFC is included in handling any events sent using sendAction
        // from the presented VCs)
        navC.modalPresentationStyle = .currentContext
        canvasContainer.present(navC, animated: true)
        ToastWindow.shared.updateStatusBarAppearance()
    }

    /// Creates the `CameraViewController` and installs the flow callbacks
    private func createCameraViewController() -> CameraViewController {
        let vc = CameraViewController(
            userPreferences: userPreferences,
            photosViewModel: photosToAddViewModel,
            projectType: model.projectSummary.projectType
        )
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
            guard let self, let vc, let cameraVC = self.cameraVC else { return }
            self.selectPhotosFromCameraRoll(
                fromVC: vc,
                multiPhotoSelection: cameraVC.cameraViewModel.multiPhotoEnabled
            )
        }
        vc.onPhotoThumbnail = { [weak self] in
            self?.showPhotosReviewFromCameraScreen()
        }
        vc.cameraViewModel.multiPhotoAllowed = allowMultiPhotoSelection
        cameraVC = vc
        return vc
    }

    /// Store the image and proceed to the photo details selection step
    private func onPhotoTaken(
        data: Data,
        image: UIImage,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Task { @MainActor in
            do {
                if !(cameraVC?.cameraViewModel.multiPhotoEnabled ?? false) {
                    // clear when not multi-photo session
                    self.photosToAddViewModel.clear(removeFromCache: true)
                }

                // store the image in local cache and add to photosToAddViewModel
                self.photosToAddViewModel.add(
                    try await self.photosToAddViewModel.getPhotoToAdd(forJPEGData: data, image: image)
                )

                if !(cameraVC?.cameraViewModel.multiPhotoEnabled ?? false) {
                    self.nextStepAfterCamera()
                }
                completion(.success(()))
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func selectPhotosFromCameraRoll(fromVC vc: UIViewController, multiPhotoSelection: Bool) {
        var pickerConfiguration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        // in multi-photo selection preselect the photos that were already picked (in this session)
        pickerConfiguration.preselectedAssetIdentifiers = multiPhotoSelection
            ? photosToAddViewModel.photos.compactMap(\.assetIdentifier)
            : []
        pickerConfiguration.selectionLimit = multiPhotoSelection ? 0 : 1
        pickerConfiguration.filter = .images
        let picker = PHPickerViewController(configuration: pickerConfiguration)
        picker.overrideUserInterfaceStyle = .dark
        picker.delegate = self
        vc.present(picker, animated: true)
    }

    private func showPhotosReviewFromCameraScreen() {
        guard let cameraVC = cameraVC else { return }
        let vc = createPhotosReviewViewController()
        vc.onCancel = { [weak vc] in
            vc?.dismiss(animated: true)
        }

        vc.onDone = { [weak self, weak vc] removedPhotosIndices, annotations in
            guard let self = self else { return }
            // remove any photos removed in photos preview, please note that indices are stored
            // in order they were removed, so the removals should be replayed in this order
            for index in removedPhotosIndices {
                guard index < self.photosToAddViewModel.photos.count else {
                    fatalError("Tried to remove photo with out of bounds index \(index)")
                }
                self.photosToAddViewModel.remove(photoAtIndex: index)
            }
            vc?.dismiss(animated: true)
            Task { @MainActor in
                do {
                    try await self.updateAnnotations(annotations)
                } catch {
                    ToastWindow.shared.showError(text: "Failed to update the annotations")
                }
            }
        }
        vc.modalPresentationStyle = .fullScreen
        cameraVC.present(vc, animated: true)
    }

    private func showPhotosReviewFromDetailsScreen(interactivePresentation: UIPercentDrivenInteractiveTransition?) {
        guard let detailsVC = detailsVC else { return }
        let vc = createPhotosReviewViewController()

        // hides photos review controller and possibly updates the annotations
        let hideReviewController: ([Int], Bool, [Annotations?], Bool)
            -> Void = { [weak self, weak vc] removedPhotosIndices, updateAnnotations, annotations, dismissVC in
                guard let self = self, let vc = vc else { return }

                // remove any photos removed in photos preview, please note that indices are stored
                // in order they were removed, so the removals should be replayed in this order
                for index in removedPhotosIndices {
                    guard index < self.photosToAddViewModel.photos.count else {
                        fatalError("Tried to remove photo with out of bounds index \(index)")
                    }
                    self.photosToAddViewModel.remove(photoAtIndex: index)
                }

                if let detailsVC = self.detailsVC, vc.currentPage > 0 {
                    // when hiding the photos review make sure that image gallery in details screen
                    // shows the same page as the last viewed on photos review
                    detailsVC.headerVC.galleryVC.setCurrentPage(vc.currentPage)
                }
                if dismissVC {
                    vc.dismiss(animated: true)
                }
                if updateAnnotations {
                    Task { @MainActor in
                        do {
                            try await self.updateAnnotations(annotations)
                        } catch {
                            ToastWindow.shared.showError(text: "Failed to update the annotations")
                        }
                    }
                }
            }

        vc.onCancel = {
            hideReviewController([], false, [], true)
        }
        vc.onDone = { removedPhotosIndices, annotations in
            hideReviewController(removedPhotosIndices, true, annotations, true)
        }

        let galleryVC = detailsVC.headerVC.galleryVC!
        vc.currentPage = galleryVC.currentPage
        let transitioningDelegate = FullscreenImageGalleryTransitioningDelegate(
            fromGallery: galleryVC,
            toFullscreenGallery: vc,
            interactivePresentation: interactivePresentation
        )
        transitioningDelegate.onDismissedInteractively = {
            // when dismissed interactively, we want to treat it as if user tapped "done" - so
            // save all changes.
            hideReviewController(vc.removedPhotosIndices, true, vc.resultAnnotations, false)
        }
        vc.fullscreenTransitioningDelegate = transitioningDelegate
        vc.transitioningDelegate = transitioningDelegate
        vc.modalPresentationStyle = .custom
        detailsVC.present(vc, animated: true)
    }

    /// Update annotations for photos, generate new annotated images (if annotations changed) and store in LocalFiles
    @MainActor
    private func updateAnnotations(_ photosAnnotations: [Annotations?]) async throws {
        for index in photosAnnotations.indices {
            let photoAnnotations = photosAnnotations[index]
            let previousPhotoAnnotations = photosToAddViewModel.photos[index].annotations
            if previousPhotoAnnotations != photoAnnotations {
                let mediaKey = photosToAddViewModel.photos[index].mediaKey
                let localFileURL = localFiles.fileURL(forKey: mediaKey)
                let imageData = try Data(contentsOf: localFileURL)
                let annotatedImageData: Data
                if let annotations = photoAnnotations {
                    guard let image = UIImage(data: imageData) else {
                        throw "Failed to load the image"
                    }
                    // create annotated image
                    annotatedImageData = AnnotationsRenderer.render(annotations: annotations, onImage: image)
                } else {
                    // Annotated photo should be removed, but this requires support from server side,
                    // so just upload non annotated as annotated for now
                    annotatedImageData = imageData
                }
                // store annotated image locally and add to pending uploads
                let annotatedMediaKey = MediaKey.localFilesKeyWithAutoStorageVersion(
                    projectId: mediaKey.projectId,
                    uploadId: mediaKey.uploadId,
                    fileType: mediaKey.fileType,
                    annotated: true,
                    thumbnailNumber: mediaKey.thumbnailNumber
                )
                try await localFiles.store(annotatedImageData, forKey: annotatedMediaKey)
                try await localFiles.generateAndStoreThumbnails(annotatedImageData, forKey: annotatedMediaKey)
                photosToAddViewModel.setAnnotations(
                    photoAnnotations,
                    annotatedMediaKey: annotatedMediaKey,
                    atIndex: index
                )
            }
        }
    }

    private func createPhotosReviewViewController() -> FullscreenImageGalleryViewController<MediaKey> {
        FullscreenImageGalleryViewController(
            imageDataProviderFactory: { [localFiles] in
                localFiles.imageProvider(forKey: $0)
            },
            photoKeys: photosToAddViewModel.photos.map(\.mediaKey),
            annotations: photosToAddViewModel.photos.map(\.annotations),
            removePhotosEnabled: true,
            userPreferences: userPreferences
        )
    }

    private func nextStepAfterCamera() {
        if showDetailsScreen {
            selectPhotoDetails()
        } else if skipPhotoLocationSelection {
            // if we skip photo location and annotations then finalize the flow now
            finalizeFromCameraScreen()
        } else {
            // go straight to photo location
            canvasContainer.dismiss(animated: true)
            ToastWindow.shared.updateStatusBarAppearance()
            selectPhotoLocation()
        }
    }

    /// push photo details view controller onto the navigation controller for the camera screen
    private func selectPhotoDetails() {
        if let navC = canvasContainer.presentedViewController as? UINavigationController {
            navC.pushViewController(createPhotoDetailsViewController(), animated: true)
        } else {
            // if skipCameraScreen then this is the first step and we need to show the navigation controller
            let navC = UINavigationController(rootViewController: createPhotoDetailsViewController())
            navC.modalPresentationStyle = .currentContext
            canvasContainer.present(navC, animated: true)
        }
    }

    /// Creates the `PhotoDetailsViewController` and installs the flow callbacks
    private func createPhotoDetailsViewController() -> PhotoDetailsViewController {
        let vc = PhotoDetailsViewController(
            localFiles: localFiles,
            photosViewModel: photosToAddViewModel,
            tagsViewModel: tagsViewModel,
            initialDescription: photoDescription
        )
        if skipCameraScreen {
            vc.backButtonLabel = String(localized: "Cancel")
            vc.backButtonImage = nil
        }
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
            if self.skipCameraScreen {
                self.canvasContainer.dismiss(animated: true)
                self.stop(removeCurrentPhotosToAddFromCache: true)
            } else {
                detailsVC.navigationController?.popViewController(animated: true)
            }
            self.detailsVC = nil
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
        vc.onViewsBuilt = { [weak self] in
            guard let self, self.autoShowPhotosReviewFromDetailsScreen else { return }
            self.autoShowPhotosReviewFromDetailsScreen = false
            self.showPhotosReviewFromDetailsScreen(interactivePresentation: nil)
        }
        detailsVC = vc
        return vc
    }

    /// Adapt the UI for the location selection
    private func selectPhotoLocation() {
        canvasDelegateId = canvasContainer.canvasViewController.addDelegate(self)
        controls.showTopViewController(
            iconName: "mappin.and.ellipse", title: String(localized: "Add Location"),
            animated: true
        )
        showConfirmationCard()
        controls.showPanAndZoomIndicatorView(aboveView: confirmationCardVC!.view)
        controls.showCanvasSelectorButton(aboveView: confirmationCardVC!.view)
        controls.showCanvasSourceSelectorButton(aboveView: controls.canvasSelectorButton!)
        controls.canvasSourceSelectorButton?.isHidden = model.currentCanvas.canvasSources.count <= 1
        showPinTypeSelector()
        showPins()
    }

    /// go back from photo location selection to photo details
    private func onPhotoLocationBack() {
        dismissPhotoLocationSelectionUI()
        // setup a navigation controller with camera and photo details, so user can go back
        // from the details to camera screen
        let navC = UINavigationController()
        if !skipCameraScreen {
            navC.viewControllers.append(createCameraViewController())
        }
        if showDetailsScreen {
            navC.viewControllers.append(createPhotoDetailsViewController())
        }
        navC.modalPresentationStyle = .currentContext
        canvasContainer.present(navC, animated: true)
        ToastWindow.shared.updateStatusBarAppearance()
    }

    /// Store the photo(s) and stop the flow
    /// Invoked from the camera screen when `skipPhotoLocationSelection` is `true` and `annotationEnabled` is `false`
    private func finalizeFromCameraScreen() {
        guard let cameraVC = cameraVC else { return }

        finalize(
            withProgressInViewController: cameraVC,
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
            withProgressInViewController: detailsVC,
            cleanup: {
                detailsVC.nextButton.configuration?.showsActivityIndicator = false
            },
            onSuccess: {
                self.canvasContainer.dismiss(animated: true)
                self.stop(removeCurrentPhotosToAddFromCache: false)
            }
        )
    }

    /// Store the photo location, save all the data and stop the flow
    /// Invoked from the confirmation card in the photo location selection
    private func finalizeFromConfirmationCard() {
        guard let confirmationCardVC = confirmationCardVC else { return }

        confirmationCardVC.setInactiveWithActivityIndicator(on: confirmationCardVC.doneButton)

        geometryId = pinsDisplay?.selectedPin?.id

        finalize(
            withProgressInViewController: canvasContainer,
            cleanup: {
                confirmationCardVC.setActive()
            },
            onSuccess: {
                self.dismissPhotoLocationSelectionUI()
                self.stop(removeCurrentPhotosToAddFromCache: false)
            }
        )
    }

    /// Add progress view to given `progressHostView` and stores the photo data.
    /// Runs the `cleanup` callback once the photo storage completes (whether successfull or not)
    /// Runs the `onSuccess` callback when storing data succeeded
    /// Both callbacks are dispatched on the main queue
    private func finalize(
        withProgressInViewController progressHost: UIViewController,
        cleanup: @escaping () -> Void,
        onSuccess: @escaping () -> Void
    ) {
        // show activity view (a spinner) that covers the screen disabling any user interactions
        let activityView = UIActivityIndicatorView(style: .large)
        activityView.backgroundColor = .black.withAlphaComponent(0.3)
        activityView.color = .Pink_03
        progressHost.view.addSubview(activityView)
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
                    self.showError(withMessage: error.localizedDescription, in: progressHost)
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
        if userSettings.saveImagesToDevice {
            let mediaKeysToSave = photosToAddViewModel.photos
                .filter { $0.assetIdentifier == nil } // save only photos that are not from camera roll already
                .map(\.mediaKey)
            for key in mediaKeysToSave {
                let localFileURL = localFiles.fileURL(forKey: key)
                let imageData = try Data(contentsOf: localFileURL)
                guard let image = UIImage(data: imageData) else { throw "Failed to save image to device" }
                try await image._writeToSavedPhotosAlbum()
            }
        }
        if let geometryId = geometryId {
            let commands = try photosToAddViewModel.photos.map { photoToAdd in
                try self.model.addPhoto(
                    photoToAdd,
                    tags: tagsViewModel.selectedTags,
                    description: photoDescription,
                    toCollaborationForGeometryId: geometryId,
                    correlationId: correlationId
                )
            }
            try await model.run(commands)
            resultGeometryId = geometryId
            newCollaborationCreated = false
            shouldEditCollaboration = false
        } else {
            let geometryId = generateRealmId()
            let isTask = (pinTypeOption.pinType == .task) || (pinTypeOption == .copyPin && pinToCopy?.status != nil)
            try await model.run(model.createCollaboration(
                at: canvasContainer.annotationsMapView.mapboxMap.cameraState.center,
                in: model.currentCanvas,
                withGeometryId: geometryId,
                isTask: isTask,
                name: pinToCopy?.name,
                collaborationDescription: pinToCopy?.collaborationDescription,
                assignee: pinToCopy?.assignee?.participation == .active ? pinToCopy?.assignee : nil,
                dueDate: pinToCopy?.dueDateTimestamp,
                tags: pinToCopy?.tags.map(TagViewModel.init(fromTag:)) ?? [],
                followerIds: pinToCopy?.followers.map(\.id) ?? [],
                photosToAdd: photosToAddViewModel.photos,
                uploadTags: tagsViewModel.selectedTags,
                uploadDescription: photoDescription
            ))
            resultGeometryId = geometryId
            newCollaborationCreated = true
            shouldEditCollaboration = pinTypeOption != .copyPin
            userPreferences.lastPinTypeOption = pinTypeOption
            if let pinToCopy = pinToCopy {
                userPreferences.addLastCopiedPin(pinToCopy.id, forProjectId: model.projectId)
            }
        }
        userPreferences.addRecentTagIds(tagsViewModel.selectedTags.map(\.id), forProjectId: model.projectId)
    }
}

// MARK: - photo location selection UI adaptation

extension AddPhotoFlowController {
    /// remove the photo location selection views/handlers
    private func dismissPhotoLocationSelectionUI() {
        if let canvasDelegateId = canvasDelegateId {
            canvasContainer.canvasViewController.removeDelegate(id: canvasDelegateId)
        }
        if let switchPinTypeCardVC = switchPinTypeCardVC {
            switchPinTypeCardVC.hideCard(animated: true) {
                self.canvasContainer.removeCard(cardViewController: switchPinTypeCardVC)
            }
            self.switchPinTypeCardVC = nil
        }
        if let photosPreviewCardVC = photosPreviewCardVC {
            photosPreviewCardVC.hideCard(animated: true) {
                self.canvasContainer.removeCard(cardViewController: photosPreviewCardVC)
            }
            self.photosPreviewCardVC = nil
        }
        if let confirmationCardVC = confirmationCardVC {
            confirmationCardVC.hideCard(animated: true) {
                self.canvasContainer.removeCard(cardViewController: confirmationCardVC)
            }
            self.confirmationCardVC = nil
        }
        controls.hideTopViewController(animated: false)
        controls.hidePanAndZoomIndicatorView(animated: false)
        pinsDisplay?.stop()
        pinsDisplay = nil
        canvasObservation?.invalidate()
        canvasObservation = nil
        controls.hideCanvasSelectorButton()
        controls.hideCanvasSourceSelectorButton()
    }

    private func createAddPhotoPinsDisplay() {
        pinsDisplay = AddPhotoPinsDisplay(
            canvasContainer: canvasContainer,
            model: model,
            image: photosToAddViewModel.photos.first!.thumbnail
        )
        pinsDisplay?.autoSelectInitialLocation = autoSelectInitialLocation
        pinsDisplay?.onSelectedPinChange = { [weak self] pinPoint in
            if let geometryId = pinPoint?.id {
                self?.hidePinTypeSelector()
                self?.showPhotosPreview(forGeometry: geometryId, animated: true)
            } else {
                self?.hidePhotosPreview(animated: true)
                self?.showPinTypeSelector()
            }
        }
    }

    /// Starts the pin handler that adds the pins to the canvas and allows for the selection
    private func showPins() {
        createAddPhotoPinsDisplay()
        pinsDisplay?.start()
        pinsDisplay?.photoPinView?.pinType = pinTypeOption.pinType
        canvasObservation = model.observe(\.currentCanvas) { [weak self] _, _ in
            guard let self = self else { return }
            self.controls.canvasSourceSelectorButton?.isHidden = self.model.currentCanvas.canvasSources.count <= 1
            self.reloadGeometriesPinsDisplay()
            self.hidePhotosPreview(animated: true)
        }
    }

    /// Reload the geometries pins display.
    /// It stops the current pins display, creates a new one and starts it if the previous one was started (maybe it was temporarily stopped,
    /// then we need the new one to be stopped too)
    private func reloadGeometriesPinsDisplay() {
        let start = pinsDisplay?.geometriesPinsDisplay.started ?? false
        pinsDisplay?.stop()
        createAddPhotoPinsDisplay()
        if start {
            pinsDisplay?.start()
            pinsDisplay?.photoPinView?.pinType = pinTypeOption.pinType
        }
    }

    /// Presents a card with cancel/confirm and registers callbacks for user actions
    private func showConfirmationCard() {
        confirmationCardVC = AddPhotoConfirmationViewController()
        confirmationCardVC!.onBack = { [weak self] in
            self?.onPhotoLocationBack()
        }
        confirmationCardVC!.onDone = { [weak self] in
            guard let self = self else { return }
            if self.pinTypeOption == .copyPin {
                let copyPinCardVC = CopyPinCardViewController(
                    projectModel: self.model,
                    userPreferences: userPreferences
                )
                copyPinCardVC.onPinSelected = { [weak self] pin in
                    guard let self = self else { return }
                    // handle copy pin
                    self.pinToCopy = pin
                    self.finalizeFromConfirmationCard()
                }
                // nothing to do for onAddPin, user has to select a different option
                copyPinCardVC.installAndShowCard(in: self.canvasContainer, inView: self.canvasContainer.controls)
            } else {
                self.finalizeFromConfirmationCard()
            }
        }
        canvasContainer.installCard(
            cardViewController: confirmationCardVC!,
            inView: canvasContainer.controls,
            cardConfig: CardConfiguration(interactive: false, showSafeAreaBlur: true)
        )
        confirmationCardVC!.showCard(animated: true)
        confirmationCardVC!.showNextButton = pinTypeOption == .copyPin
    }

    private func showPinTypeSelector() {
        guard let confirmationCardVC = confirmationCardVC else { return }
        if switchPinTypeCardVC == nil {
            let pinTypeVC = SwitchPinTypeCardViewController(
                availableTypes: [.createPhoto, .createTask, .copyPin],
                initialType: pinTypeOption,
                confirmationVC: confirmationCardVC
            )
            pinTypeVC.onPinTypeChange = { [weak self] pinTypeOption in
                self?.pinTypeOption = pinTypeOption
            }
            canvasContainer.installCard(
                cardViewController: pinTypeVC,
                inView: canvasContainer.controls,
                cardConfig: CardConfiguration(initialCardPosition: .max, interactive: false)
            )
            // move photos preview below confirmation
            canvasContainer.controls.insertSubview(pinTypeVC.view, belowSubview: confirmationCardVC.view)
            switchPinTypeCardVC = pinTypeVC
        }

        guard let switchPinTypeCardVC = switchPinTypeCardVC else { return }

        confirmationCardVC.showDarkBorder = true
        switchPinTypeCardVC.showCard(animated: true)
        updateBottomViewsConstraints()
    }

    private func hidePinTypeSelector() {
        confirmationCardVC?.showDarkBorder = false
        if let switchPinTypeCardVC = switchPinTypeCardVC {
            switchPinTypeCardVC.hideCard(animated: true)
        }
        updateBottomViewsConstraints()
    }

    /// shows the photos for given geometryId
    private func showPhotosPreview(forGeometry geometryId: String, animated: Bool) {
        guard let confirmationCardVC = confirmationCardVC else { return }
        let photosPreviewVC = PhotosPreviewViewController(
            model: model,
            mediaCache: mediaCache,
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
        updateBottomViewsConstraints()
    }

    /// Hide the currently shown photos preview
    private func hidePhotosPreview(animated: Bool) {
        confirmationCardVC?.showDarkBorder = false
        if let photosPreviewCardVC = photosPreviewCardVC {
            photosPreviewCardVC.hideCard(animated: animated) {
                self.canvasContainer.removeCard(cardViewController: photosPreviewCardVC)
            }
            self.photosPreviewCardVC = nil
        }
        updateBottomViewsConstraints()
    }

    /// Update constraints for views attached to the bottom card (panAndZoomIndicatorView and canvasSelectorButton).
    /// They are attached to confirmation card, but if photos preview or pin type selector is shown above confirmation they should be
    /// reattached one of them (only one is shown at a time)
    private func updateBottomViewsConstraints() {
        let bottomViewToAttachControls: UIView?
        if let switchPinTypeCardVC = switchPinTypeCardVC,
           let card = switchPinTypeCardVC.cardDragging,
           !card.isCardHidden
        {
            bottomViewToAttachControls = switchPinTypeCardVC.view
        } else if let photosPreviewCardVC = photosPreviewCardVC,
                  let card = photosPreviewCardVC.cardDragging,
                  !card.isCardHidden
        {
            bottomViewToAttachControls = photosPreviewCardVC.view
        } else if let confirmationCardVC = confirmationCardVC {
            bottomViewToAttachControls = confirmationCardVC.view
        } else {
            bottomViewToAttachControls = nil
        }
        guard let bottomViewToAttachControls = bottomViewToAttachControls else { return }
        controls.anchorPanAndZoomIndicatorView(aboveView: bottomViewToAttachControls)
        if let canvasSelectorButton = controls.canvasSelectorButton {
            // anchor to photos preview
            canvasSelectorButton.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().inset(12)
                make.bottom.equalTo(bottomViewToAttachControls.snp.top).offset(-12)
            }
        }
    }
}

/// CanvasViewControllerDelegate
extension AddPhotoFlowController: CanvasViewControllerDelegate {
    func canvasCameraChanged(reason: CanvasCameraChangeReason) {
        if reason == .pan || reason == .zoom {
            controls.hidePanAndZoomIndicatorView(animated: true)
        }
    }

    func canvasTapRecognized(at _: CGPoint) {}
    func canvasLongPressRecognized(at _: CGPoint) {}
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
        activityView.backgroundColor = .black.withAlphaComponent(0.3)
        activityView.color = .Pink_03
        picker.view.addSubview(activityView)
        activityView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        activityView.startAnimating()

        Task {
            let updatePhotosError = await photosToAddViewModel.update(
                withPickerResults: results,
                multiPhotoSelection: cameraVC?.cameraViewModel.multiPhotoEnabled ?? false
            )
            DispatchQueue.main.async {
                activityView.removeFromSuperview()
                picker.dismiss(animated: true)
                if let updatePhotosError, let cameraVC = self.cameraVC {
                    let errorMessage: String
                    if results.count == 1 {
                        errorMessage = "The photo couldn't be added. " + updatePhotosError.localizedDescription
                    } else {
                        errorMessage = "Some of the photos couldn't be added. " + updatePhotosError.localizedDescription
                    }
                    self.showError(withMessage: errorMessage, in: cameraVC)
                }
                if updatePhotosError == nil, !(self.cameraVC?.cameraViewModel.multiPhotoEnabled ?? false),
                   !self.photosToAddViewModel.photos.isEmpty
                {
                    self.nextStepAfterCamera()
                }
            }
        }
    }
}

/// PhotosToAddViewModel delegate
extension AddPhotoFlowController: PhotosToAddViewModelDelegate {
    /// When the last photo is removed automatically hide the photos review screen and get back to camera screen (if in details)
    /// In case it's configured to `skipCameraScreen` then after last photo is removed the flow is aborted
    func photoRemoved(atIndex _: Int) {
        if photosToAddViewModel.photos.isEmpty {
            if skipCameraScreen {
                canvasContainer.dismiss(animated: true)
                stop(removeCurrentPhotosToAddFromCache: true)
            } else if let cameraVC, detailsVC != nil {
                /// Hack: animated presentation of photos review leaves the presenting vc with alpha = 0, restore here manually
                /// as there won't be custom animated transitioning running for this case because there are no images to
                /// transition between
                cameraVC.navigationController?.view.alpha = 1.0
                // all photos removed while in detailsVC => navigate back to camera
                cameraVC.navigationController?.popToViewController(cameraVC, animated: true)
                detailsVC = nil
            }
        }
    }
}
