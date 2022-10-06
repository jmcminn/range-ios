import Foundation
import OSLog
import UIKit

/// Custom UIEvent sent by views to trigger certain actions defined in `CollaborationFlowActions` and related to `Upload`
final class UploadEvent: UIEvent {
    let upload: Upload
    init(_ upload: Upload) {
        self.upload = upload
    }
}

/// Protocol defining actions that collaboration flow can perform.
/// Required by the views sending actions, so they can use selectors for these functions.
@objc protocol CollaborationFlowActions: AnyObject {
    /// Notifies the flow that tags were selected for `Upload` provided in the event. This will results in the flow triggering
    /// tags editing
    func tagsSelected(sender: Any?, event: UploadEvent)
}

/// Manages displaying collaboration window
class CollaborationFlowController: UIResponder {
    unowned let model: ProjectModel
    unowned let imageCaches: ImageCaches
    unowned let canvasContainer: CanvasContainerViewController

    /// callback to notify that collaboration window is closing
    var onCollaborationClose: (() -> Void)?

    /// Currently shown collaboration
    var collaboration: Collaboration?
    /// currently shown collaboration window
    var collaborationVC: CollaborationViewController?
    /// the view covering the collaboration window in full screen mode (when the collaboration window card is in max position)
    var collaborationHeaderCoverVC: CollaborationHeaderCoverViewController?

    /// FABs (floating action buttons)
    var actionButtons: [RoundShadowButton]!

    /// When adding photos from collaboration window
    var addPhotosFlow: AddPhotoFlowController?

    /// When editing tags for upload
    var editTagsVC: SearchAndSelectTagsViewController?

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

    deinit {
        stop()
    }

    /// Prepare for showing collaboration windows
    func start() {
        setupFABs()
    }

    /// Cleanup after showing collaboration windows. The flow controller is not usable after a call to this function
    func stop() {
        removeFABs()
    }

    /// Create CollaborationViewController and setup the callbacks
    private func createCollaborationViewController(forCollaboration collaboration: Collaboration)
        -> CollaborationViewController
    {
        let collaborationVC = CollaborationViewController(
            imageCaches: imageCaches,
            projectModel: model,
            collaboration: collaboration
        )
        collaborationVC.customNextResponder = self
        collaborationVC.onClose = { [weak self] in
            self?.onCollaborationClose?()
        }
        collaborationVC.onAddPhotos = { [weak self] in
            self?.startAddPhotosFlow()
        }
        return collaborationVC
    }

    /// Finds the first collaboration for this geometry and show its window
    func showCollaborationWindow(forGeometry geometryId: String, animated: Bool) {
        if let geometry = model.mainRealm.object(ofType: Geometry.self, forPrimaryKey: geometryId),
           let feature = geometry.features.first,
           let collaboration = feature.collaborations.first
        {
            self.collaboration = collaboration
            let collaborationVC = createCollaborationViewController(forCollaboration: collaboration)

            canvasContainer.installCard(
                cardViewController: collaborationVC,
                inView: canvasContainer.controls,
                cardConfig: CardConfiguration(initialCardPosition: .medium, allowsFullScreen: true)
            )
            // move collaboration window behind fabs
            canvasContainer.controls.insertSubview(collaborationVC.view, belowSubview: actionButtons[0])
            collaborationVC.cardDragging?.delegate = self

            // check if already showing, if so then ignore animated and replace instantly
            if self.collaborationVC != nil {
                self.collaborationVC?.cardDragging?.delegate = nil
                hideCollaborationWindow(animated: false)
                setCollaborationHeaderCoverHidden(true, animated: false)
                setFABsHidden(true, animated: false)
                collaborationVC.showCard(animated: false)
            } else {
                collaborationVC.showCard(animated: animated)
            }
            addCollaborationHeaderCover()
            self.collaborationVC = collaborationVC
        } else {
            Logger.model.warning("""
                Trying to present collaboration window for geometry
                \(geometryId, privacy: .public) with no collaboration
            """)
        }
    }

    /// Hide the currently shown collaboration window (and the header cover)
    func hideCollaborationWindow(animated: Bool) {
        if let collaborationVC = collaborationVC {
            collaborationVC.cardDragging?.delegate = nil
            collaborationVC.hideCard(animated: animated) {
                self.canvasContainer.removeCard(cardViewController: collaborationVC)
            }
            self.collaborationVC = nil
        }
        setCollaborationHeaderCoverHidden(true, animated: animated)
        setFABsHidden(true, animated: animated)
        removeCollaborationHeaderCover()
    }

    /// Adds the top cover for collaboration window. Initially with alpha = 0
    private func addCollaborationHeaderCover() {
        guard let collaboration = collaboration else { return }
        if let collaborationHeaderCoverVC = collaborationHeaderCoverVC,
           collaborationHeaderCoverVC.collaboration.id == collaboration.id
        {
            // already added
            return
        }
        let collaborationHeaderCoverVC = CollaborationHeaderCoverViewController(collaboration: collaboration)
        collaborationHeaderCoverVC.onClose = { [weak self] in
            self?.onCollaborationClose?()
        }
        canvasContainer.add(childController: collaborationHeaderCoverVC, toView: canvasContainer.controls)
        collaborationHeaderCoverVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview()
        }
        collaborationHeaderCoverVC.view.alpha = 0
        self.collaborationHeaderCoverVC = collaborationHeaderCoverVC
    }

    private func removeCollaborationHeaderCover() {
        guard let collaborationHeaderCoverVC = collaborationHeaderCoverVC else { return }
        canvasContainer.remove(childController: collaborationHeaderCoverVC)
        self.collaborationHeaderCoverVC = nil
    }

    /// hides/shows the view controller covering the top of of the screen
    private func setCollaborationHeaderCoverHidden(_ hidden: Bool, animated: Bool) {
        let alpha = hidden ? 0.0 : 1.0
        if let collaborationHeaderCoverVC = collaborationHeaderCoverVC {
            if animated {
                UIView.animate(withDuration: 0.2) {
                    collaborationHeaderCoverVC.view.alpha = alpha
                }

            } else {
                collaborationHeaderCoverVC.view.alpha = alpha
            }
        }
    }
}

// MARK: FABs (floating action buttons)

extension CollaborationFlowController {
    private func setupFABs() {
        let addPhotosButton = RoundShadowButton(image: UIImage(systemName: "camera") ?? UIImage(), style: .blue)
        addPhotosButton.addTarget(self, action: #selector(startAddPhotosFlow), for: .touchUpInside)
        canvasContainer.controls.addSubview(addPhotosButton)
        addPhotosButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalTo(canvasContainer.controls.safeAreaLayoutGuide.snp.bottom).offset(-12)
        }

        let addAttachmentButton = RoundShadowButton(image: UIImage(systemName: "paperclip") ?? UIImage())
        canvasContainer.controls.addSubview(addAttachmentButton)
        addAttachmentButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalTo(addPhotosButton.snp.top).offset(-12)
        }

        let addCommentButton = RoundShadowButton(image: UIImage(systemName: "bubble.right") ?? UIImage())
        canvasContainer.controls.addSubview(addCommentButton)
        addCommentButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalTo(addAttachmentButton.snp.top).offset(-12)
        }

        actionButtons = [addPhotosButton, addAttachmentButton, addCommentButton]

        setFABsHidden(true, animated: false)
    }

    private func removeFABs() {
        actionButtons.forEach { $0.removeFromSuperview() }
    }

    private func setFABsHidden(_ hidden: Bool, animated: Bool) {
        let alpha = hidden ? 0.0 : 1.0
        if animated {
            UIView.animate(withDuration: 0.2) { [weak self] in
                self?.actionButtons.forEach { $0.alpha = alpha }
            }
        } else {
            actionButtons.forEach { $0.alpha = alpha }
        }
    }
}

// MARK: Card dragging delegate

extension CollaborationFlowController: CardDraggingDelegate {
    // hide collaboration when the window is minimized
    func cardWillChangePosition(_ position: CardPosition) {
        if position == .min {
            onCollaborationClose?()
        }
        // only show the header cover and FABs in .max position
        setCollaborationHeaderCoverHidden(position != .max, animated: true)
        setFABsHidden(position != .max, animated: true)
    }

    /// Animate the collaboration header cover and FABs alpha as user is dragging the collaboration window card
    func cardHeightUpdated(_ height: CGFloat) {
        // show/hide the header cover
        guard let collaborationVC = collaborationVC,
              let cardDragging = collaborationVC.cardDragging,
              let collaborationHeaderCoverVC = collaborationHeaderCoverVC else { return }
        // HACK: the height reported by dragging includes the safeAreaInsets while the height
        // requested by card presentable (collaborationVC) does not...
        let realHeight = height - cardDragging.containerView.safeAreaInsets.bottom
        let fullHeight = collaborationVC.height(forContainer: cardDragging.containerView, cardPosition: .max)
        // alpha is 1 when full height - 100 and then drops to 0 on a distance of 20 points
        // the 100 and 20 are arbitrary numbers selected to make the alpha transition fast (20)
        // and to start it early (100 + 20 points before height reaches the full height)
        let headerAlpha = max(0, min(1, 1.0 - (fullHeight - realHeight - 100) / 20))
        collaborationHeaderCoverVC.view.alpha = headerAlpha
        // show buttons later than header
        let fabsAlpha = max(0, min(1, 1.0 - (fullHeight - realHeight) / 20))
        actionButtons.forEach { $0.alpha = fabsAlpha }
    }
}

/// Add photos sub flow
private extension CollaborationFlowController {
    @objc func startAddPhotosFlow() {
        guard let geometryId = collaboration?.feature.first?.geometry.first?.id else {
            // the collaboration should be selected and have a geometry... (this shouldn't really happen)
            return
        }
        addPhotosFlow = AddPhotoFlowController(model: model, imageCaches: imageCaches, canvasContainer: canvasContainer)
        // preselect the geometryId as the add photos flow will not include pin placement
        // (we are adding to the currently showing collaboration window)
        addPhotosFlow?.geometryId = geometryId
        addPhotosFlow?.skipPhotoLocationSelection = true
        addPhotosFlow?.onStop = { [weak self] in
            self?.addPhotosFlow = nil
        }
        addPhotosFlow?.start { [weak self] started in
            if !started {
                self?.addPhotosFlow = nil
            }
        }
    }
}

/// Edit tags for upload sub flow
extension CollaborationFlowController: CollaborationFlowActions {
    func tagsSelected(sender _: Any?, event: UploadEvent) {
        let upload = event.upload
        let selectedTags = Array(upload.tags.map { TagViewModel(fromTag: $0) })
        let tagsViewModel = TagsViewModel(model: model, initialSelectedTags: selectedTags)
        editTagsVC = SearchAndSelectTagsViewController(tagsViewModel: tagsViewModel)
        editTagsVC!.onClose = { [weak self, weak upload] in
            guard let self = self, let upload = upload else { return }
            self.updateTagsIfChanged(forUpload: upload)
        }
        canvasContainer.installCard(
            cardViewController: editTagsVC!,
            inView: canvasContainer.controls,
            cardConfig: CardConfiguration(initialCardPosition: .max, interactive: false, showOverlay: true)
        )
        editTagsVC!.showCard(animated: true)
    }

    /// Update tags for given upload and close the editTagsVC. The tags are taken from the current editTagsVC
    /// If tags haven't changed, just close the editTagsVC
    /// If updating failed give user a choice to retry or abort (close the editTagsVC and not save changes)
    private func updateTagsIfChanged(forUpload upload: Upload) {
        guard let editTagsVC = editTagsVC else { return }

        let selectedTags = editTagsVC.tagsViewModel.selectedTags
        let selectedTagIdsSet = Set(selectedTags.map(\.id))
        let existingTagIdsSet = Set(upload.tags.map(\.id))

        let closeEditTagsVC = {
            editTagsVC.hideCard(animated: true) {
                self.canvasContainer.removeCard(cardViewController: editTagsVC)
            }
        }

        // just close the editTagsVC if the same tags
        guard selectedTagIdsSet != existingTagIdsSet else {
            closeEditTagsVC()
            return
        }

        runCommandsWithProgress(
            commands: model.update(tags: selectedTags, forUpload: upload),
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
                    self?.updateTagsIfChanged(forUpload: upload)
                }))
                alert.addAction(UIAlertAction(title: "Abort", style: .destructive, handler: { _ in
                    closeEditTagsVC()
                }))
                editTagsVC.present(alert, animated: true)
            }
        )
    }

    /// Shows the activity indicator making the UI not interactive, runs provided commands and runs one of the provided blocks depending
    /// on the success of the commands.
    private func runCommandsWithProgress(commands: [Command],
                                         onSuccess: @escaping () -> Void,
                                         onFailure: @escaping (Error) -> Void)
    {
        // show activity view (a spinner) that covers the screen disabling any user interactions
        let activityView = UIActivityIndicatorView(style: .large)
        activityView.backgroundColor = .black.withAlphaComponent(0.2)
        activityView.color = .Pink_03
        canvasContainer.overlays.addSubview(activityView)
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
                try await model.runCommands(commands)
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
