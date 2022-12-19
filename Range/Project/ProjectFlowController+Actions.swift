import Foundation
import OSLog
import RealmSwift
import UIKit

/// Custom UIEvent sent by views to trigger certain actions and related to given `Object`
/// The way responder chain works forces us to pass objects (Upload, Comment, etc.) as Object as there's no way to use generics
/// to define the custom UIEvent (as they need to later match the signature of action functions which are Objective-C action(sender: Any?, event: UIEvent?)
/// (See "Discussion" in https://developer.apple.com/documentation/uikit/uiapplication/1622946-sendaction)
final class FlowEvent: UIEvent {
    enum Source {
        case media // the event is originating from the media collection view
    }

    let object: Object
    let source: Source?
    init(_ object: Object, source: Source? = nil) {
        self.object = object
        self.source = source
    }
}

/// Protocol defining actions that project flow can perform.
/// Required by the views sending actions, so they can use selectors for these functions.
/// See https://swiftrocks.com/understanding-the-ios-responder-chain.html for more info
@objc protocol ProjectFlowActions: AnyObject {
    /// show the Media card view controller with all project uploads
    func showMediaAction()
    /// Select and change the current canvas for project
    func selectCanvasAction()
    /// Show fullscreen media view for given upload
    func showFullscreenMediaAction(sender: Any?, event: FlowEvent)
    /// Show collaboration window for collaboration passed in the event
    func showCollaborationAction(sender: Any?, event: FlowEvent)
    /// Edit description of Upload passed in the event
    func editDescriptionAction(sender: Any?, event: FlowEvent)
    /// Edit tags for Collaboration or Upload
    func editTagsAction(sender: Any?, event: FlowEvent)
}

extension ProjectFlowController: ProjectFlowActions {
    func selectCanvasAction() {
        let canvases = [PDFCanvas](model.mainRealm.objects(PDFCanvas.self).sorted(by: \PDFCanvas.pageNumber))
        CanvasSelectorCardViewController(
            title: String(localized: "Source Selector"),
            canvases: canvases,
            selectedCanvas: model.currentCanvas,
            onCanvasSelected: { [weak self] canvas in
                guard let self = self else { return }
                guard self.model.currentCanvas != canvas else { return }
                self.model.currentCanvas = canvas
            }
        ).installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    func showMediaAction() {
        mediaVC = MediaCardViewController(
            projectModel: model,
            imageCaches: imageCaches,
            title: String(localized: "Media"),
            uploads: model.mainRealm.objects(Upload.self).where
                { $0.placeholder == false && $0.fileType == .image },
            onUploadSelected: { _ in
            }
        ).installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    func showFullscreenMediaAction(sender _: Any?, event: FlowEvent) {
        guard let upload = event.object as? Upload else { return }
        let fromMedia = event.source == .media
        fullscreenMediaVC = FullscreenMediaCardViewController(
            projectModel: model,
            imageCaches: imageCaches,
            upload: upload,
            // show button only from media, otherwise it's from collaboration so user can just close
            // the fullscreen media and be back in collaboration
            showCollaborationButton: fromMedia
        )
        .installAndShowCard(
            in: canvasContainer,
            inView: canvasContainer.controls,
            // media view already shows the overlay so don't show in this case
            showOverlay: !fromMedia
        )
    }

    func showCollaborationAction(sender _: Any?, event: FlowEvent) {
        guard let collaboration = event.object as? Collaboration,
              let geometry = collaboration.feature.first?.geometry.first,
              let canvas = geometry.canvas.first
        else { return }
        // update the canvas
        model.currentCanvas = canvas
        // reload the pins (it only reloads if canvas has changed)
        reloadGeometriesPinsDisplay(useNativeViews: debugSettings.nativeViewsForPins) {
            guard let pinsDisplay = self.pinsDisplay else { return }
            if let pin = pinsDisplay.pinForGeometryId(geometry.id) {
                // select the pin (which will trigger showing the collaboration window)
                pinsDisplay.setSelectedPin(pin)
                let canvasVC = self.canvasContainer.pdfCanvasViewController
                // pan the canvas to center on the pin
                canvasVC.animatePanAndZoom(
                    cameraCenter: pin.point.coordinates,
                    mapboxZoom: canvasVC.mapView.mapboxMap.cameraState.zoom
                )
            }
        }
    }

    func editDescriptionAction(sender _: Any?, event: FlowEvent) {
        guard let upload = event.object as? Upload else { return }
        TextCardViewController(
            title: "Description",
            initialText: upload.uploadDescription,
            onTextSaved: { [weak self] newDescription in
                self?.updateDescription(newDescription, forUpload: upload)
            }
        )
        .installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    private func updateDescription(_ description: String?, forUpload upload: Upload) {
        model.run(model.update(description: description, forUpload: upload)) { error in
            if error != nil { ToastWindow.shared.showError(text: "Failed to update the description") }
        }
    }

    func editTagsAction(sender _: Any?, event: FlowEvent) {
        let object = event.object
        let initialTags: [TagViewModel]
        if let upload = object as? Upload {
            initialTags = Array(upload.tags.map { TagViewModel(fromTag: $0) })
        } else if let collaboration = object as? Collaboration {
            initialTags = Array(collaboration.tags.map { TagViewModel(fromTag: $0) })
        } else {
            fatalError("tagsSelected action not implemented for \(event.object)")
        }
        let tagsViewModel = TagsViewModel(model: model, initialSelectedTags: initialTags)
        let editTagsVC = SearchAndSelectTagsViewController(tagsViewModel: tagsViewModel)
        editTagsVC.onClose = { [weak self] in
            guard let self = self else { return }
            self.updateTagsIfChanged(fromViewController: editTagsVC, forObject: object)
        }
        canvasContainer.installCard(
            cardViewController: editTagsVC,
            inView: canvasContainer.controls,
            cardConfig: CardConfiguration(initialCardPosition: .max, interactive: false, showOverlay: true)
        )
        editTagsVC.showCard(animated: true)
    }

    /// Update tags for given collaboration or upload and close the editTagsVC. The tags are taken from the current editTagsVC
    /// If tags haven't changed, just close the editTagsVC
    /// If updating failed give user a choice to retry or abort (close the editTagsVC and not save changes)
    private func updateTagsIfChanged(
        fromViewController editTagsVC: SearchAndSelectTagsViewController,
        forObject object: Object
    ) {
        let selectedTags = editTagsVC.tagsViewModel.selectedTags
        let closeEditTagsVC = {
            editTagsVC.hideCard(animated: true) {
                self.canvasContainer.removeCard(cardViewController: editTagsVC)
            }
        }

        let command: Command?
        if let collaboration = object as? Collaboration {
            command = model.update(tags: selectedTags, forCollaboration: collaboration)
        } else if let upload = object as? Upload {
            command = model.update(tags: selectedTags, forUpload: upload)
        } else {
            fatalError("updateTagsIfChanged not implemented for \(object)")
        }

        guard let command = command else {
            closeEditTagsVC()
            return
        }

        runCommandWithProgress(
            command: command,
            onSuccess: { [weak self] in
                guard let self = self else { return }
                UserDefaults.addRecentTagIds(selectedTags.map(\.id), forProjectId: self.model.projectId)
                closeEditTagsVC()
            },
            onFailure: { error in
                let alert = UIAlertController(
                    title: "Updating tags error",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Retry", style: .default, handler: { [weak self] _ in
                    // try again
                    self?.updateTagsIfChanged(fromViewController: editTagsVC, forObject: object)
                }))
                alert.addAction(UIAlertAction(title: "Abort", style: .destructive, handler: { _ in
                    closeEditTagsVC()
                }))
                editTagsVC.present(alert, animated: true)
            }
        )
    }
}

// MARK: - running commands

extension ProjectFlowController {
    /// Shows the activity indicator making the UI not interactive, runs provided commands and runs one of the provided blocks depending
    /// on the success of the commands.
    /// If the command is nil this function doesn nothing
    private func runCommandWithProgress(command: Command,
                                        onSuccess: @escaping () -> Void,
                                        onFailure: @escaping (Error) -> Void)
    {
        // show activity view (a spinner) that covers the screen disabling any user interactions
        let activityView = UIActivityIndicatorView(style: .large)
        activityView.backgroundColor = .black.withAlphaComponent(0.3)
        activityView.color = .Pink_03
        view.addSubview(activityView)
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
                    }
                }
                try await model.run(command)
                DispatchQueue.main.async {
                    onSuccess()
                }
            } catch {
                Logger.model.error("finalize error: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    onFailure(error)
                }
            }
        }
    }
}
