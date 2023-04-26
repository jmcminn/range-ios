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
    /// Select and change the current canvas source for canvas
    func selectCanvasSourceAction()
    /// Select canvas filters
    func selectCanvasFiltersAction()
    /// Show fullscreen media view for given upload
    func showFullscreenMediaAction(sender: Any?, event: FlowEvent)
    /// Show fullscreen media view and open comments tab for given upload
    func showFullscreenMediaCommentsAction(sender: Any?, event: FlowEvent)
    /// Show collaboration window for collaboration passed in the event
    func showCollaborationAction(sender: Any?, event: FlowEvent)
    /// Edit description of Upload passed in the event
    func editDescriptionAction(sender: Any?, event: FlowEvent)
    /// Edit tags for Collaboration or Upload
    func editTagsAction(sender: Any?, event: FlowEvent)
    /// Show more menu for FlowEvent.object
    func moreAction(sender: Any?, event: FlowEvent)
    /// show the Task list card view controller with project tasks
    func showTaskListAction()
}

extension ProjectFlowController: ProjectFlowActions {
    func selectCanvasAction() {
        let canvases = [Canvas](model.mainRealm.objects(Canvas.self))
            .filter { !$0.canvasSources.isEmpty }
            .sorted(by: Canvas.sortingOrder)
        CanvasSelectorCardViewController(
            title: String(localized: "Canvas Selector"),
            canvases: canvases,
            selectedCanvas: model.currentCanvas,
            onCanvasSelected: { [weak self] canvas in
                guard let self = self else { return }
                guard self.model.currentCanvas != canvas else { return }
                do {
                    try self.model.setCurrentCanvas(canvas)
                } catch {
                    ToastWindow.shared.showError(text: "Canvas failed to load")
                }
            }
        ).installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    func selectCanvasSourceAction() {
        let canvasSources = [CanvasSource](model.currentCanvas.canvasSources).sorted(by: CanvasSource.sortingOrder)
        CanvasSourceSelectorCardViewController(
            title: String(localized: "Map Layers"),
            canvasSources: canvasSources,
            selectedCanvasSource: model.currentCanvas.currentCanvasSource,
            onCanvasSourceSelected: { [weak self] canvasSource in
                guard let self = self else { return }
                guard self.model.currentCanvas.currentCanvasSource != canvasSource else { return }
                self.model.currentCanvas.currentCanvasSource = canvasSource
            }
        ).installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    func selectCanvasFiltersAction() {
        let canvasFiltersCardVC = CanvasFiltersCardViewController(model: model, canvasFilters: canvasFilters)
        canvasFiltersCardVC.onCancel = { [weak self] in
            guard let self = self else { return }
            UserDefaults.setCanvasFilters(canvasFilters, forProjectId: model.projectId)
        }
        canvasFiltersCardVC.installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    func showMediaAction() {
        mediaVC = MediaCardViewController(
            projectModel: model,
            mediaCache: mediaCache,
            title: String(localized: "All Media"),
            uploads: model.mainRealm.objects(Upload.self).where { $0.placeholder == false },
            canvasContainer: canvasContainer
        ).installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    func showTaskListAction() {
        taskListVC = TaskListCardViewController(projectModel: model)
            .installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    func showFullscreenMediaAction(sender _: Any?, event: FlowEvent) {
        showFullscreenMedia(forEvent: event)
    }

    func showFullscreenMediaCommentsAction(sender _: Any?, event: FlowEvent) {
        showFullscreenMedia(forEvent: event, initialMode: .comments)
    }

    private func showFullscreenMedia(
        forEvent event: FlowEvent,
        initialMode mode: FullscreenMediaCardViewController.Mode = .summary
    ) {
        guard let upload = event.object as? Upload else { return }
        let fromMedia = event.source == .media
        fullscreenMediaVC = FullscreenMediaCardViewController(
            projectModel: model,
            mediaCache: mediaCache,
            upload: upload,
            // show button only from media, otherwise it's from collaboration so user can just close
            // the fullscreen media and be back in collaboration
            showCollaborationButton: fromMedia,
            initialMode: mode
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
        do {
            try model.setCurrentCanvas(canvas)
        } catch {
            ToastWindow.shared.showError(text: "Canvas failed to load")
        }
        // reload the pins (it only reloads if canvas has changed)
        reloadGeometriesPinsDisplay(useNativeViews: debugSettings.nativeViewsForPins) {
            guard let pinsDisplay = self.pinsDisplay else { return }
            if let pin = pinsDisplay.pinForGeometryId(geometry.id) {
                // select the pin (which will trigger showing the collaboration window)
                pinsDisplay.setSelectedPin(pin)
                let canvasVC = self.canvasContainer.canvasViewController
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

// MARK: - more menu actions

extension ProjectFlowController {
    func moreAction(sender _: Any?, event: FlowEvent) {
        if let collaboration = event.object as? Collaboration {
            guard !collaboration.isInvalidated else { return }
            var actions: [ActionItem] = collaboration.status == nil
                ? [ActionItem(title: String(localized: "Convert to Task Pin"), imageName: "checkmark.circle", handler: {
                    self.confirmAndConvertPhotoCollaborationToTask(collaboration)
                })]
                : []
            actions.append(contentsOf: [
                ActionItem(
                    title: String(localized: "Update Location"), imageName: "mappin.and.ellipse",
                    handler: { [weak self] in
                        self?.moveCollaboration(collaboration)
                    }
                ),
                ActionItem(
                    title: collaboration.isArchived ? String(localized: "Unarchive") : String(localized: "Archive"),
                    imageName: "archivebox",
                    handler: { [weak self] in
                        self?.toggleCollaborationArchived(collaboration)
                    }
                ),
                ActionItem(
                    title: String(localized: "Delete"), imageName: "trash", style: .destructive,
                    handler: { [weak self] in
                        self?.confirmAndDeleteCollaboration(collaboration)
                    }
                ),
            ])
            let menuTitle = collaboration.status == nil
                ? String(localized: "Photo Pin Menu")
                : String(localized: "Task Pin Menu")

            ActionSelectorCardViewController(
                icon: UIImage(systemName: "ellipsis"), title: menuTitle, actions: actions
            )
            .installAndShowCard(in: canvasContainer)
        } else if let upload = event.object as? Upload {
            guard !upload.isInvalidated else { return }
            ActionSelectorCardViewController(
                icon: UIImage(systemName: "ellipsis"),
                title: "More Menu",
                actions: [
                    ActionItem(
                        title: upload.isImage ? "Delete Photo" : "Delete File",
                        imageName: "trash",
                        style: .destructive,
                        handler: {
                            self.confirmAndDeleteUpload(upload)
                        }
                    ),
                ]
            ).installAndShowCard(in: canvasContainer)
        } else if let comment = event.object as? Comment {
            guard !comment.isInvalidated else { return }
            let commentOrNote = comment.isNote ? "Note" : "Comment"
            ActionSelectorCardViewController(
                icon: UIImage(systemName: "ellipsis"),
                title: "More Menu",
                actions: [
                    ActionItem(title: "Edit \(commentOrNote)", imageName: "pencil", handler: {
                        self.editComment(comment)
                    }),
                    ActionItem(title: "Delete \(commentOrNote)", imageName: "trash", style: .destructive, handler: {
                        self.confirmAndDeleteComment(comment)
                    }),
                ]
            ).installAndShowCard(in: canvasContainer)
        }
    }

    func editComment(_ comment: Comment) {
        guard !comment.isInvalidated else { return }
        let commentVC = CommentViewController(mode: .edit)
        commentVC.commentText = comment.text
        commentVC.isNote = comment.isNote
        commentVC.onCancel = { [weak self, weak commentVC] in
            guard let self = self, let commentVC = commentVC else { return }
            commentVC.hideCard(animated: true) {
                self.removeCard(cardViewController: commentVC)
            }
        }
        commentVC.onDone = { [weak self, weak commentVC] in
            guard let self = self, let commentVC = commentVC else { return }
            let text = commentVC.commentText
            commentVC.hideCard(animated: true) {
                self.removeCard(cardViewController: commentVC)
            }
            self.model.run(self.model.update(text: text!, forComment: comment)) { error in
                if error != nil { ToastWindow.shared.showError(text: "Failed to update the comment") }
            }
        }
        installCard(
            cardViewController: commentVC,
            cardConfig: CardConfiguration(initialCardPosition: .max, interactive: false, showOverlay: true)
        )
        commentVC.showCard(animated: true)
    }

    func confirmAndConvertPhotoCollaborationToTask(_ collaboration: Collaboration) {
        guard !collaboration.isInvalidated else { return }
        ActionSelectorCardViewController(
            icon: nil,
            title: "Are you sure?",
            description: "Doing this means you can add a description, tags and assign a status, due date and assignee. The style of the map pin will also change. ",
            actions: [
                ActionItem(title: "Convert to Task Pin", imageName: "checkmark.circle", handler: {
                    self.convertPhotoCollaborationToTask(collaboration)
                }),
                ActionItem(title: "Cancel", imageName: "xmark"),
            ]
        ).installAndShowCard(in: canvasContainer)
    }

    func convertPhotoCollaborationToTask(_ collaboration: Collaboration) {
        guard !collaboration.isInvalidated else { return }
        Task {
            do {
                try await self.model.run(self.model.convertPhotoCollaborationToTask(collaboration))
                // show the window again as it's not switching automatically from photo to task layout
                collaboration.realm?.refresh()
                self.collaborationFlow.showCollaborationWindow(collaboration, animated: true)
            } catch {
                Logger.model.error("command error: \(error.localizedDescription, privacy: .public)")
                ToastWindow.shared.showError(text: "Failed to convert to task pin")
            }
        }
    }

    func confirmAndDeleteCollaboration(_ collaboration: Collaboration) {
        guard !collaboration.isInvalidated else { return }
        ActionSelectorCardViewController(
            icon: nil,
            title: "Are you sure?",
            description: collaboration.status != nil
                ? "This task pin will be deleted permanently. It can’t be recovered."
                : "This photo pin will be deleted permanently. It can’t be recovered.",
            actions: [
                ActionItem(
                    title: collaboration.status != nil ? "Delete Task Pin" : "Delete Photo Pin",
                    imageName: "trash", style: .destructive, handler: {
                        self.deleteCollaboration(collaboration)
                    }
                ),
                ActionItem(title: "Cancel", imageName: "xmark"),
            ]
        ).installAndShowCard(in: canvasContainer)
    }

    func deleteCollaboration(_ collaboration: Collaboration) {
        guard !collaboration.isInvalidated else { return }
        // hide the window first so all collaboration change listeners are unregistered
        collaborationFlow.hideCollaborationWindow(animated: true) {
            // unselect the pin
            self.pinsDisplay?.setSelectedPin(nil)
            Task {
                do {
                    try await self.model.run(self.model.delete(collaboration: collaboration))
                } catch {
                    Logger.model.error("command error: \(error.localizedDescription, privacy: .public)")
                    ToastWindow.shared.showError(text: "Failed to delete the pin")
                }
            }
        }
    }

    func confirmAndDeleteUpload(_ upload: Upload) {
        guard !upload.isInvalidated else { return }
        ActionSelectorCardViewController(
            icon: nil,
            title: "Are you sure?",
            description: "This \(upload.isImage ? "photo" : "file") will be deleted permanently. It can’t be recovered.",
            actions: [
                ActionItem(
                    title: upload.isImage ? "Delete Photo" : "Delete File",
                    imageName: "trash", style: .destructive, handler: {
                        self.deleteUpload(upload)
                    }
                ),
                ActionItem(title: "Cancel", imageName: "xmark"),
            ]
        ).installAndShowCard(in: canvasContainer)
    }

    func deleteUpload(_ upload: Upload) {
        guard !upload.isInvalidated else { return }
        // hide media/fullscreen
        if let fullscreenMediaVC = fullscreenMediaVC, fullscreenMediaVC.upload == upload {
            fullscreenMediaVC.dismissCard()
        }
        model.run(model.delete(uploads: [upload.id])) { error in
            if error !=
                nil { ToastWindow.shared.showError(text: "Failed to delete the \(upload.isImage ? "photo" : "file")") }
        }
    }

    func toggleCollaborationArchived(_ collaboration: Collaboration) {
        guard !collaboration.isInvalidated else { return }
        Task {
            do {
                try await self.model.run(self.model.toggleCollaborationArchived(collaboration: collaboration))
            } catch {
                Logger.model.error("command error: \(error.localizedDescription, privacy: .public)")
                ToastWindow.shared.showError(text:
                    "Failed to \(collaboration.isArchived ? "unarchive" : "archive") the collaboration")
            }
        }
    }

    func confirmAndDeleteComment(_ comment: Comment) {
        guard !comment.isInvalidated else { return }
        let commentOrNote = comment.isNote ? "Note" : "Comment"
        ActionSelectorCardViewController(
            icon: nil,
            title: "Are you sure?",
            description: "This \(commentOrNote.lowercased()) will be deleted permanently. It can't be recovered.",
            actions: [
                ActionItem(title: "Delete \(commentOrNote)", imageName: "trash", style: .destructive, handler: {
                    self.deleteComment(comment)
                }),
                ActionItem(title: "Cancel", imageName: "xmark"),
            ]
        ).installAndShowCard(in: canvasContainer)
    }

    func deleteComment(_ comment: Comment) {
        guard !comment.isInvalidated else { return }
        model.run(model.delete(comment: comment)) { error in
            if error != nil {
                ToastWindow.shared.showError(text: "Failed to delete the \(comment.isNote ? "note" : "comment")")
            }
        }
    }

    /// Update the location of the collaboration
    func moveCollaboration(_ collaboration: Collaboration) {
        guard !collaboration.isInvalidated else { return }
        pinsDisplay?.setSelectedPin(nil)
        movePinFlow = MovePinFlowController(
            model: model,
            collaboration: collaboration,
            canvasContainer: canvasContainer
        )
        movePinFlow?.onStop = { [weak self] _ in
            guard let self = self else { return }
            self.showDefaultCanvasUI()
            self.movePinFlow = nil
        }
        hideDefaultCanvasUI()
        movePinFlow?.start()
    }
}
