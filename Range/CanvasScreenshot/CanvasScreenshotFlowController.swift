import Foundation
import OSLog
import SwiftUI
import UIKit

/// Manages the flow of taking a screenshot of current canvas and adding it to given collaboration
/// This flow resembles (has copy paste from) the AddPhotoFlowController as it reuses the PhotoDetailsViewController
/// and has the same code for presenting the PhotosReviewViewController and updating the annotations...
/// Maybe the common logic should be somehow refactored... (when we have another flow controller that's similar?)
class CanvasScreenshotFlowController {
    let geometryId: String
    let model: ProjectModel
    let localFiles: LocalFiles
    let canvasContainer: CanvasContainerViewController

    private var selectionVC: CanvasScreenshotSelectionViewController?

    /// called when the flow finishes
    var onStop: (() -> Void)?

    /// MapboxScreenshotter is stateful, we need to keep the reference for the time of screenshot taking
    private var mapboxScreenshotter = MapboxScreenshotter()

    private let photosToAddViewModel: PhotosToAddViewModel
    private let tagsViewModel: TagsViewModel
    private var detailsVC: PhotoDetailsViewController?

    init?(
        collaboration: Collaboration,
        model: ProjectModel,
        localFiles: LocalFiles,
        canvasContainer: CanvasContainerViewController
    ) {
        guard !collaboration.isInvalidated,
              let geometryId = collaboration.feature.first?.geometry.first?.id else { return nil }
        self.geometryId = geometryId
        self.model = model
        self.localFiles = localFiles
        self.canvasContainer = canvasContainer
        photosToAddViewModel = PhotosToAddViewModel(projectId: model.projectId, localFiles: localFiles)
        tagsViewModel = TagsViewModel(model: model)
        photosToAddViewModel.addDelegate(self)
    }

    /// Show the UI for canvas screenshot
    func start() {
        selectionVC = CanvasScreenshotSelectionViewController(
            canvasViewController: canvasContainer.canvasViewController
        )
        selectionVC?.onCancel = { [weak self] in
            self?.stop(removeCurrentPhotosToAddFromCache: true)
        }
        selectionVC?.onDone = { [weak self] screenshotFrame in
            self?.takeScreenshotAndShowPhotoDetails(screenshotFrame)
        }
        canvasContainer.controls.addSubview(selectionVC!.view)
        selectionVC!.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func stop(removeCurrentPhotosToAddFromCache: Bool) {
        photosToAddViewModel.clear(removeFromCache: removeCurrentPhotosToAddFromCache)
        detailsVC?.dismiss(animated: true)
        detailsVC = nil
        selectionVC?.view.removeFromSuperview()
        selectionVC = nil
        onStop?()
    }

    @MainActor
    private func takeScreenshot(_ screenshotFrame: CGRect) async throws -> UIImage {
        guard let selectionVC else {
            fatalError("No selection view")
        }
        let activityView = showActivityView(host: selectionVC.view)

        defer {
            DispatchQueue.main.async {
                activityView.removeFromSuperview()
            }
        }

        let canvas = canvasContainer.canvasViewController.canvas

        if canvas.currentCanvasSource.type == .pdf {
            guard let pdfPage = canvasContainer.canvasViewController.pdfPage else {
                fatalError("pdf page missing for pdf canvas source")
            }
            let selectedPDFFrame = canvasContainer.canvasViewController.getPDFPageFrameForViewFrame(screenshotFrame)
            return PDFScreenshotter().takeScreenshot(page: pdfPage, selectedFrame: selectedPDFFrame)

        } else {
            return try await withCheckedThrowingContinuation { continuation in
                mapboxScreenshotter.takeScreenshot(
                    canvasSourceData: canvas.currentCanvasSource.data,
                    areaSize: screenshotFrame.size,
                    cameraState: canvasContainer.canvasViewController.mapView.mapboxMap.cameraState,
                    zoomConverter: canvasContainer.canvasViewController.zoomConverter
                ) { result in
                    switch result {
                    case let .success(image): continuation.resume(returning: image)
                    case let .failure(error): continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func takeScreenshotAndShowPhotoDetails(_ screenshotFrame: CGRect) {
        Task { @MainActor in
            do {
                let image = try await takeScreenshot(screenshotFrame)
                detailsVC = try await createPhotoDetailsViewController(image: image)
                detailsVC?.modalPresentationStyle = .fullScreen
                canvasContainer.present(detailsVC!, animated: true)
            } catch {
                ToastWindow.shared.showError(text: "Failed to add a snippet")
            }
        }
    }

    /// Creates the `PhotoDetailsViewController` and installs the flow callbacks
    @MainActor
    private func createPhotoDetailsViewController(image: UIImage) async throws -> PhotoDetailsViewController {
        guard let data = image.jpegData(compressionQuality: 0.75) else {
            throw "Cannot use image"
        }

        photosToAddViewModel.add(
            try await photosToAddViewModel.getPhotoToAdd(forJPEGData: data, image: image)
        )

        let vc = PhotoDetailsViewController(
            localFiles: localFiles,
            photosViewModel: photosToAddViewModel,
            tagsViewModel: tagsViewModel,
            initialDescription: ""
        )
        vc.backButtonLabel = String(localized: "Cancel")
        vc.backButtonImage = nil
        vc.nextButtonLabel = String(localized: "Done")
        vc.nextButtonImage = nil
        vc.onPhotoSelected = { [weak self] interactivePresentation in
            self?.showPhotosReviewFromDetailsScreen(interactivePresentation: interactivePresentation)
        }
        vc.onBack = { [weak self] in
            self?.stop(removeCurrentPhotosToAddFromCache: true)
        }
        vc.onNext = { [weak self] in
            self?.finalize()
        }
        return vc
    }

    /// show activity view (a spinner) that covers the screen disabling any user interactions
    private func showActivityView(host: UIView) -> UIActivityIndicatorView {
        let activityView = UIActivityIndicatorView(style: .large)
        activityView.backgroundColor = .black.withAlphaComponent(0.3)
        activityView.color = .Pink_03
        host.addSubview(activityView)
        activityView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        activityView.startAnimating()
        return activityView
    }

    /// Store the data and stop the flow controller
    private func finalize() {
        guard let detailsVC else {
            fatalError("No details view")
        }
        detailsVC.nextButton.configuration?.showsActivityIndicator = true
        let activityView = showActivityView(host: detailsVC.view)

        Task { @MainActor in
            do {
                // hide the spinner when data store call is finished
                defer {
                    DispatchQueue.main.async {
                        activityView.removeFromSuperview()
                        detailsVC.nextButton.configuration?.showsActivityIndicator = false
                    }
                }
                let command = try await model.addPhotos(
                    photosToAddViewModel.photos,
                    tags: tagsViewModel.selectedTags,
                    description: detailsVC.photoDescription,
                    toCollaborationForGeometryId: geometryId
                )
                try await model.run(command)
                DispatchQueue.main.async {
                    self.stop(removeCurrentPhotosToAddFromCache: false)
                }
            } catch {
                Logger.model.error("finalize error: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    ToastWindow.shared.showError(text: "Failed to add the snippet")
                }
            }
        }
    }

    private func showPhotosReviewFromDetailsScreen(interactivePresentation: UIPercentDrivenInteractiveTransition?) {
        guard let detailsVC = detailsVC else { return }
        let vc = createPhotosReviewViewController()

        // hides photos review controller and possibly updates the annotations
        let hideReviewController: ([Int], Bool, [Annotations?])
            -> Void = { [weak self, weak vc] removedPhotosIndices, updateAnnotations, annotations in
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
                vc.dismiss(animated: true)
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
            hideReviewController([], false, [])
        }
        vc.onDone = { removedPhotosIndices, annotations in
            hideReviewController(removedPhotosIndices, true, annotations)
        }

        let galleryVC = detailsVC.headerVC.galleryVC!
        vc.currentPage = galleryVC.currentPage
        let transitioningDelegate = FullscreenImageGalleryTransitioningDelegate(
            fromGallery: galleryVC,
            toFullscreenGallery: vc,
            interactivePresentation: interactivePresentation
        )
        vc.fullscreenTransitioningDelegate = transitioningDelegate
        vc.transitioningDelegate = transitioningDelegate
        vc.modalPresentationStyle = .custom
        detailsVC.present(vc, animated: true)
    }

    private func createPhotosReviewViewController() -> FullscreenImageGalleryViewController<MediaKey> {
        FullscreenImageGalleryViewController(
            imageDataProviderFactory: { [localFiles] in
                localFiles.imageProvider(forKey: $0)
            },
            photoKeys: photosToAddViewModel.photos.map(\.mediaKey),
            annotations: photosToAddViewModel.photos.map(\.annotations),
            removePhotosEnabled: true
        )
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
}

/// PhotosToAddViewModel delegate
extension CanvasScreenshotFlowController: PhotosToAddViewModelDelegate {
    /// When the last photo is removed automatically hide the photos review screen and stop the flow
    func photoRemoved(atIndex _: Int) {
        if photosToAddViewModel.photos.isEmpty {
            stop(removeCurrentPhotosToAddFromCache: true)
        }
    }
}
