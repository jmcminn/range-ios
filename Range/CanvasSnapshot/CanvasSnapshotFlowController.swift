import Foundation
import OSLog
import SwiftUI
import UIKit

/// Manages the flow of taking a snapshot of current canvas and adding it to given collaboration
/// It can also be run with no collaboration - in this case it'll add a new pin.
/// It uses the AddPhotoFlowController for photo details and pin placement screen (it just hides the first step - camera screen, and
/// instead provides the AddPhotoFlowController with a canvas snippet photo)
class CanvasSnapshotFlowController {
    let geometryId: String?
    let model: ProjectModel
    let localFiles: LocalFiles
    let mediaCache: MediaCache
    let userSettings: UserSettings
    let canvasContainer: CanvasContainerViewController

    private var selectionVC: CanvasSnapshotSelectionViewController?

    /// on Stop it returns the id of the geometry to which the photo(s) was added to (if not cancelled) and whether the
    /// collaboration was created (`true`) or existing one was used (`false`) and whether the collaboration should be edited after creation
    var onStop: ((String?, Bool?, Bool?) -> Void)?

    /// MapboxSnapshotter is stateful, we need to keep the reference for the time of snapshot taking
    private var mapboxSnapshotter = MapboxSnapshotter()

    /// Using AddPhotoFlowController after the initial snapshot taking step, to reuse the photo details screen and pin placement
    private var addPhotoFlow: AddPhotoFlowController?

    init?(
        collaboration: Collaboration?,
        model: ProjectModel,
        localFiles: LocalFiles,
        mediaCache: MediaCache,
        userSettings: UserSettings,
        canvasContainer: CanvasContainerViewController
    ) {
        if let collaboration, !collaboration.isInvalidated {
            geometryId = collaboration.feature.first?.geometry.first?.id
        } else {
            geometryId = nil
        }
        self.model = model
        self.localFiles = localFiles
        self.mediaCache = mediaCache
        self.userSettings = userSettings
        self.canvasContainer = canvasContainer
    }

    /// Show the UI for canvas snapshot
    func start() {
        selectionVC = CanvasSnapshotSelectionViewController(
            canvasViewController: canvasContainer.canvasViewController
        )
        selectionVC?.onCancel = { [weak self] in
            guard let self else { return }
            self.selectionVC?.view.removeFromSuperview()
            self.selectionVC = nil
            self.onStop?(self.geometryId, nil, nil)
        }
        selectionVC?.onDone = { [weak self] snapshotFrame in
            self?.takeSnapshotAndStartAddPhotoFlow(snapshotFrame)
        }
        canvasContainer.controls.addSubview(selectionVC!.view)
        selectionVC!.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @MainActor
    private func takeSnapshot(_ snapshotFrame: CGRect) async throws -> UIImage {
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
            let selectedPDFFrame = canvasContainer.canvasViewController.getPDFPageFrameForViewFrame(snapshotFrame)
            return PDFSnapshotter().takeSnapshot(page: pdfPage, selectedFrame: selectedPDFFrame)

        } else {
            return try await withCheckedThrowingContinuation { continuation in
                mapboxSnapshotter.takeSnapshot(
                    canvasSourceData: canvas.currentCanvasSource.data,
                    areaSize: snapshotFrame.size,
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

    private func takeSnapshotAndStartAddPhotoFlow(_ snapshotFrame: CGRect) {
        Task { @MainActor in
            do {
                let image = try await takeSnapshot(snapshotFrame)

                guard let data = image.jpegData(compressionQuality: 0.75) else {
                    throw "Cannot use image"
                }

                let addPhotoFlow = AddPhotoFlowController(
                    model: model,
                    localFiles: localFiles,
                    mediaCache: mediaCache,
                    userSettings: userSettings,
                    canvasContainer: canvasContainer
                )

                if let existingSnippetTag = addPhotoFlow.tagsViewModel.allTags
                    .first(where: { $0.name == "snippet" })
                {
                    addPhotoFlow.tagsViewModel.set(tagWithId: existingSnippetTag.id, selected: true)
                } else {
                    let snippetTag = TagViewModel(newTagWithName: "snippet")
                    addPhotoFlow.tagsViewModel.add(tag: snippetTag)
                    addPhotoFlow.tagsViewModel.set(tagWithId: snippetTag.id, selected: true)
                }

                addPhotoFlow.photosToAddViewModel.add(
                    try await addPhotoFlow.photosToAddViewModel.getPhotoToAdd(forJPEGData: data, image: image)
                )

                addPhotoFlow.skipCameraScreen = true
                // always show the details screen, even if it was deactivated in the "normal" photo flow
                addPhotoFlow.skipDetailsScreen = false

                // TODO: 2747 auto open annotation view

                if let geometryId {
                    // adding snapshot to given collaboration
                    addPhotoFlow.geometryId = geometryId
                    addPhotoFlow.skipPhotoLocationSelection = true
                } else {
                    // adding snapshot with no collaboration - allow user to select or create a new one
                    // Don't autoselect the initial location - we want it to default to whatever center
                    // point is currently selected (as it's the center of the snapshot)
                    addPhotoFlow.autoSelectInitialLocation = false
                }

                addPhotoFlow.onStop = { [weak self] geometryId, newlyCreated, shouldEdit in
                    guard let self else { return }
                    self.addPhotoFlow = nil
                    self.onStop?(geometryId, newlyCreated, shouldEdit)
                }

                self.addPhotoFlow = addPhotoFlow

                addPhotoFlow.start { [weak self] started in
                    guard let self else { return }
                    if started {
                        // remove the selection view when switching to photo flow, there's no going
                        // back, if user cancels the photo flow we're aborting canvas snapshot flow
                        self.selectionVC?.view.removeFromSuperview()
                        self.selectionVC = nil
                    } else {
                        self.addPhotoFlow = nil
                    }
                }
            } catch {
                ToastWindow.shared.showError(text: "Failed to add a snippet")
            }
        }
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
}
