import Foundation
import OSLog
import RealmSwift
import UIKit

/// Protocol defining actions that collaboration flow can perform.
/// Required by the views sending actions, so they can use selectors for these functions.
/// See https://swiftrocks.com/understanding-the-ios-responder-chain.html for more info
@objc protocol CollaborationFlowActions: AnyObject {
    /// When "Add photos" button in the Collaboration window header or CTA was tapped
    func addPhotosAction()
    /// When "Add comment" button in the Collaboration window header or CTA was tapped
    func addCommentAction()
    /// Notifies the flow that tags were selected for `Upload` provided in the event. This will results in the flow triggering
    /// tags editing
    func tagsSelectedAction(sender: Any?, event: FlowEvent)
    /// Show more menu for FlowEvent.object
    func moreAction(sender: Any?, event: FlowEvent)
    /// Toggle the complete state of the Note
    func toggleCompleteAction(sender: Any?, event: FlowEvent)
    /// Edit due date for collaboration
    func editDueDateAction()
    /// Edit collaboration name
    func editNameAction()
    /// Edit collaboration description
    func editDescriptionAction()
    /// Edit collaboration status
    func editStatusAction()
    /// Edit collaboration assignee
    func editAssigneeAction()
}

/// Manages displaying collaboration window
/// This flow controller is a UIViewController to be part of the UI responder chain but its view is a passthrough view so
/// it does not interfere with canvas interactions.
/// All subviews and cards are added to this view controller view.
class CollaborationFlowController: UIViewController, CollaborationFlowActions {
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
    /// Bottom view with CTAs showing when user scrolls the collaboration view so it's CTAs hide behind the header cover
    var collaborationBottomVC: CollaborationBottomViewController?

    private var collaborationScrollViewObserver: NSKeyValueObservation?

    /// When adding photos from collaboration window
    var addPhotosFlow: AddPhotoFlowController?

    /// When editing tags for upload
    var editTagsVC: SearchAndSelectTagsViewController?

    /// Remember the text for the last comment that was cancelled, so when showing the next AddCommentViewController
    /// for the same collaboration use this text. It's reset when the current collaboration changes
    var lastCancelledCommentText: String! = ""

    ///
    /// - Parameters:
    ///     - model: - the project model
    ///     - images: - access to images
    ///     - canvas: - the flow will operate on this canvas
    init(model: ProjectModel, imageCaches: ImageCaches, canvasContainer: CanvasContainerViewController) {
        self.model = model
        self.imageCaches = imageCaches
        self.canvasContainer = canvasContainer
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Override loadView to customise view to be a passthrough view.
    override func loadView() {
        view = PassthroughView()
    }

    /// Prepare for showing collaboration windows
    func start() {
        /// add self to canvasContainer
        canvasContainer.add(childController: self, toView: canvasContainer.controls)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    /// Cleanup after showing collaboration windows. The flow controller is not usable after a call to this function
    func stop() {
        removeBottomCard()
        canvasContainer.remove(childController: self)
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
        collaborationVC.onClose = { [weak self] in
            self?.onCollaborationClose?()
        }
        collaborationVC.onNameUpdated = { [weak self] newName in
            self?.updateName(newName)
        }
        if let scrollView = collaborationVC.drivingScrollView() {
            scrollView.forwardDelegateInvocations(to: self)
            collaborationScrollViewObserver = scrollView.observe(\.contentSize) { [weak self] _, _ in
                self?.collaborationScrollViewContentSizeChanged()
            }
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

            installCard(
                cardViewController: collaborationVC,
                cardConfig: CardConfiguration(initialCardPosition: .medium, allowsFullScreen: true)
            )
            // move collaboration window behind bottom card
            if let collaborationBottomVC = collaborationBottomVC {
                view.insertSubview(collaborationVC.view, belowSubview: collaborationBottomVC.view)
            }
            collaborationVC.cardDragging?.delegate = self

            // check if already showing, if so then ignore animated and replace instantly
            if self.collaborationVC != nil {
                self.collaborationVC?.cardDragging?.delegate = nil
                let previousCardHeight = self.collaborationVC?.cardDragging?.cardHeight
                hideCollaborationWindow(animated: false)
                setCollaborationHeaderCoverHidden(true, animated: false)
                setBottomCardHidden(true, animated: false)
                collaborationVC.showCard(animated: false)
                if let previousCardHeight = previousCardHeight, let newCardDragging = collaborationVC.cardDragging {
                    // animate the height from previous height, so there's no jump
                    newCardDragging.setCardHeight(previousCardHeight)
                    newCardDragging.setPosition(newCardDragging.position, withVelocity: 0, animated: true)
                }
            } else {
                collaborationVC.showCard(animated: animated)
            }
            addCollaborationHeaderCover()
            setupBottomCard()
            self.collaborationVC = collaborationVC
        } else {
            Logger.model.warning("""
                Trying to present collaboration window for geometry
                \(geometryId, privacy: .public) with no collaboration
            """)
        }
    }

    /// Hide the currently shown collaboration window (and the header cover)
    func hideCollaborationWindow(animated: Bool, completion: (() -> Void)? = nil) {
        if let collaborationVC = collaborationVC {
            collaborationVC.cardDragging?.delegate = nil
            collaborationVC.hideCard(animated: animated) {
                self.removeCard(cardViewController: collaborationVC)
                completion?()
            }
            if let scrollView = collaborationVC.drivingScrollView() {
                scrollView.cancelForwardingDelegateInvocations(to: self)
            }
            collaborationScrollViewObserver?.invalidate()
            collaborationScrollViewObserver = nil
            self.collaborationVC = nil
        } else {
            completion?()
        }
        setCollaborationHeaderCoverHidden(true, animated: animated)
        setBottomCardHidden(true, animated: animated)
        removeCollaborationHeaderCover()
        lastCancelledCommentText = ""
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
        add(childController: collaborationHeaderCoverVC)
        collaborationHeaderCoverVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview()
        }
        collaborationHeaderCoverVC.view.alpha = 0
        self.collaborationHeaderCoverVC = collaborationHeaderCoverVC
    }

    private func removeCollaborationHeaderCover() {
        guard let collaborationHeaderCoverVC = collaborationHeaderCoverVC else { return }
        remove(childController: collaborationHeaderCoverVC)
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

// MARK: - bottom card

extension CollaborationFlowController {
    private func setupBottomCard() {
        guard collaborationBottomVC == nil else { return }
        collaborationBottomVC = CollaborationBottomViewController()
        installCard(
            cardViewController: collaborationBottomVC!,
            cardConfig: CardConfiguration(initialCardPosition: .min,
                                          interactive: false)
        )
        collaborationBottomVC!.showCard(animated: false)
    }

    private func removeBottomCard() {
        guard let collaborationBottomVC = collaborationBottomVC else { return }
        removeCard(cardViewController: collaborationBottomVC)
        self.collaborationBottomVC = nil
    }

    private func setBottomCardHidden(_ hidden: Bool, animated: Bool) {
        guard let cardDragging = collaborationBottomVC?.cardDragging else { return }
        let newPosition: CardPosition = hidden ? .min : .medium
        guard cardDragging.position != newPosition else { return }

        cardDragging.setPosition(newPosition, withVelocity: 0, animated: animated) { [weak self] in
            guard let self = self else { return }
            // adjust the feed bottom content inset so user can still scroll to the bottom of the feed
            // when the bottom card is overlapping the table view
            // - safeAreaInsets.bottom = the feed is not covering the bottom safe area while the card height includes it
            guard let scrollView = self.collaborationVC?.feedVC.tableView else { return }
            scrollView.contentInset = UIEdgeInsets(
                top: 0,
                left: 0,
                bottom: max(0, cardDragging.cardHeight - self.view.safeAreaInsets.bottom),
                right: 0
            )
            scrollView.scrollIndicatorInsets = scrollView.contentInset
        }
    }
}

// MARK: - listen to position of collaboration view CTAs

extension CollaborationFlowController: UIScrollViewDelegate {
    /// When the collaboration view content is scrolled we show/hide the FABs based on the current collaboration CTAs position against the header cover
    func scrollViewDidScroll(_: UIScrollView) {
        updateBottomCardVisibility()
    }

    /// Observing contentSize to update the bottom card visibility (switching to show "less updates" in the feed may result in short
    /// content, so the CTAs in the collaboration view can be revealed, so we bottom card should be hidden)
    private func collaborationScrollViewContentSizeChanged() {
        updateBottomCardVisibility()
    }

    /// show/hide bottom card when the corresponding collaboration view CTAs hide behind the header cover/show again
    private func updateBottomCardVisibility() {
        guard let collaborationVC = collaborationVC,
              let headerCoverVC = collaborationHeaderCoverVC else { return }

        let ctas: UIView = collaborationVC.detailsVC.ctas

        let headerCoverBottom = headerCoverVC.view.frame.maxY
        let ctasTop = headerCoverVC.view.convert(ctas.frame, from: collaborationVC.detailsVC.view).minY

        // once the collaboration view CTAs get behind the cover let's show the bottom card
        if headerCoverBottom - ctasTop >= ctas.frame.height {
            setBottomCardHidden(false, animated: true)
        } else {
            setBottomCardHidden(true, animated: true)
        }
    }
}

// MARK: Card dragging delegate

extension CollaborationFlowController: CardDraggingDelegate {
    // hide collaboration when the window is minimized
    func cardWillChangePosition(_ position: CardPosition) {
        if position == .min || position == .max {
            // if the keyboard is showing then hide it when the card is changing the position
            // (this will happen when editing the collaboration name)
            collaborationVC?.view.endEditing(true)
        }
        if position == .min {
            onCollaborationClose?()
        }
        // only show the header cover and FABs in .max position
        setCollaborationHeaderCoverHidden(position != .max, animated: true)
    }

    /// Animate the collaboration header cover and FABs alpha as user is dragging the collaboration window card
    func cardHeightUpdated(_: CGFloat) {
        guard let collaborationVC = collaborationVC,
              let collaborationHeaderCoverVC = collaborationHeaderCoverVC else { return }

        let headerCoverBottom = collaborationHeaderCoverVC.view.frame.maxY
        let collaborationViewTop = collaborationVC.view.frame.minY

        // once the collaboration view gets behind the cover at least by 30 points (arbitrary, visually
        // selected value) let's change the alpha to 1 on the distance of 20 points
        let headerCoverAlpha = max(0, min(1, (headerCoverBottom - 30 - collaborationViewTop) / 20))
        collaborationHeaderCoverVC.view.alpha = headerCoverAlpha

        updateBottomCardVisibility()
    }
}

// MARK: - add photos sub flow for current collaboration

extension CollaborationFlowController {
    func addPhotosAction() {
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

// MARK: - add comment/note to current collaboration

extension CollaborationFlowController {
    func addCommentAction() {
        let addCommentVC = CommentViewController(mode: .add)
        addCommentVC.commentText = lastCancelledCommentText
        addCommentVC.onCancel = { [weak self, weak addCommentVC] in
            guard let self = self, let addCommentVC = addCommentVC else { return }
            self.lastCancelledCommentText = addCommentVC.commentText
            addCommentVC.hideCard(animated: true) {
                self.removeCard(cardViewController: addCommentVC)
            }
        }
        addCommentVC.onDone = { [weak self, weak addCommentVC] in
            guard let self = self, let addCommentVC = addCommentVC else { return }
            self.addComment(fromCommentVC: addCommentVC)
        }
        installCard(
            cardViewController: addCommentVC,
            cardConfig: CardConfiguration(initialCardPosition: .max, interactive: false, showOverlay: true)
        )
        addCommentVC.showCard(animated: true)
    }

    private func addComment(fromCommentVC addCommentVC: CommentViewController) {
        addCommentVC.hideCard(animated: true) {
            self.removeCard(cardViewController: addCommentVC)
        }
        guard let collaboration = collaboration else { return }

        model.run(model.addComment(
            commentText: addCommentVC.commentText,
            isNote: addCommentVC.isNote,
            toCollaboration: collaboration.id
        )) { error in
            if error != nil {
                ToastWindow.shared.showError(text: "Failed to add the comment")
            } else {
                self.lastCancelledCommentText = ""
            }
        }
    }
}

// MARK: - edit tags for collaboration or upload

extension CollaborationFlowController {
    func tagsSelectedAction(sender _: Any?, event: FlowEvent) {
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
        editTagsVC = SearchAndSelectTagsViewController(tagsViewModel: tagsViewModel)
        editTagsVC!.onClose = { [weak self] in
            guard let self = self else { return }
            self.updateTagsIfChanged(forObject: object)
        }
        installCard(
            cardViewController: editTagsVC!,
            cardConfig: CardConfiguration(initialCardPosition: .max, interactive: false, showOverlay: true)
        )
        editTagsVC!.showCard(animated: true)
    }

    /// Update tags for given collaboration or upload and close the editTagsVC. The tags are taken from the current editTagsVC
    /// If tags haven't changed, just close the editTagsVC
    /// If updating failed give user a choice to retry or abort (close the editTagsVC and not save changes)
    private func updateTagsIfChanged(forObject object: Object) {
        guard let editTagsVC = editTagsVC else { return }
        let selectedTags = editTagsVC.tagsViewModel.selectedTags

        let closeEditTagsVC = {
            editTagsVC.hideCard(animated: true) {
                self.removeCard(cardViewController: editTagsVC)
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
                    self?.updateTagsIfChanged(forObject: object)
                }))
                alert.addAction(UIAlertAction(title: "Abort", style: .destructive, handler: { _ in
                    closeEditTagsVC()
                }))
                editTagsVC.present(alert, animated: true)
            }
        )
    }
}

// MARK: - edit status

extension CollaborationFlowController {
    func editStatusAction() {
        guard let collaboration = collaboration else { return }
        guard collaboration.status != nil else { return } // not a task
        let statuses = [Status](model.mainRealm.objects(Status.self))
        StatusPickerCardViewController(
            title: "Assign Status",
            statuses: statuses,
            selectedStatus: collaboration.status, onStatusPicked: { [weak self] newStatus in
                self?.updateStatus(newStatus)
            }
        )
        .installAndShowCard(in: self)
    }

    private func updateStatus(_ status: Status) {
        guard let collaboration = collaboration else { return }
        model.run(model.update(status: status, forCollaboration: collaboration)) { error in
            if error != nil { ToastWindow.shared.showError(text: "Failed to update the status") }
        }
    }
}

// MARK: - edit name

extension CollaborationFlowController {
    func editNameAction() {
        guard let cardDragging = collaborationVC?.cardDragging else { return }
        // reset the card height to medium (this action is triggered from full screen when
        // name label is tapped in the header cover), so the nameField is visible and can become first
        // responder
        cardDragging.setPosition(.medium, withVelocity: 0, animated: true)
        // make the nameField first responder, the rest is handler by CollaborationViewController
        // that is a delegate of the text field. So editing the name can also be started directly
        // by tapping on the nameField.
        collaborationVC?.nameField.becomeFirstResponder()
    }
}

// MARK: - edit name

extension CollaborationFlowController {
    func editDescriptionAction() {
        guard let collaboration = collaboration else { return }
        TextCardViewController(
            title: "Description",
            initialText: collaboration.collaborationDescription,
            onTextSaved: { [weak self] newDescription in
                self?.updateDescription(newDescription)
            }
        )
        .installAndShowCard(in: self)
    }

    private func updateDescription(_ description: String?) {
        guard let collaboration = collaboration else { return }
        model.run(model.update(description: description, forCollaboration: collaboration)) { error in
            if error != nil { ToastWindow.shared.showError(text: "Failed to update the description") }
        }
    }
}

// MARK: - edit assignee

extension CollaborationFlowController {
    func editAssigneeAction() {
        let users = [Participant](model.mainRealm.objects(Participant.self))
        guard let collaboration = collaboration else { return }
        UserPickerCardViewController(
            title: "Assignee",
            users: users,
            selectedUser: collaboration.assignee,
            onUserPicked: { [weak self] newAssignee in
                self?.updateAssignee(newAssignee)
            }
        )
        .installAndShowCard(in: self)
    }

    private func updateAssignee(_ assignee: Participant?) {
        guard let collaboration = collaboration else { return }
        model.run(model.update(assignee: assignee, forCollaboration: collaboration)) { error in
            if error != nil { ToastWindow.shared.showError(text: "Failed to update the assignee") }
        }
    }
}

// MARK: - edit due date

extension CollaborationFlowController {
    func editDueDateAction() {
        guard let collaboration = collaboration else { return }
        DatePickerCardViewController(
            title: "Due Date",
            timeZone: model.projectSummary.timeZone,
            initialSelectedDate: collaboration.dueDateTimestamp,
            onDatePicked: { [weak self] newDueDate in
                self?.updateDueDate(newDueDate)
            }
        )
        .installAndShowCard(in: self)
    }

    private func updateDueDate(_ dueDate: Date?) {
        guard let collaboration = collaboration else { return }
        model.run(model.update(dueDate: dueDate, forCollaboration: collaboration)) { error in
            if error != nil { ToastWindow.shared.showError(text: "Failed to update the due date") }
        }
    }
}

// MARK: - name update UI action

extension CollaborationFlowController {
    private func updateName(_ name: String) {
        collaborationVC?.view.endEditing(true)
        guard let collaboration = collaboration else { return }
        model.run(model.update(name: name, forCollaboration: collaboration)) { error in
            if error != nil { ToastWindow.shared.showError(text: "Failed to update the name") }
        }
    }
}

// MARK: - comment/note actions

extension CollaborationFlowController {
    func moreAction(sender _: Any?, event: FlowEvent) {
        if let collaboration = event.object as? Collaboration {
            ActionSelectorCardViewController(
                icon: UIImage(systemName: "ellipsis"),
                title: "More Menu",
                actions: [
                    ActionItem(
                        title: collaboration.isArchived ? "Unarchive" : "Archive",
                        imageName: "archivebox",
                        handler: {
                            self.toggleCollaborationArchived(collaboration)
                        }
                    ),
                    ActionItem(title: "Delete", imageName: "trash", style: .destructive, handler: {
                        self.confirmAndDeleteCollaboration(collaboration)
                    }),
                ]
            ).installAndShowCard(in: canvasContainer)
        } else if let upload = event.object as? Upload {
            ActionSelectorCardViewController(
                icon: UIImage(systemName: "ellipsis"),
                title: "More Menu",
                actions: [
                    ActionItem(title: "Delete Photo", imageName: "trash", style: .destructive, handler: {
                        self.confirmAndDeleteUpload(upload)
                    }),
                ]
            ).installAndShowCard(in: canvasContainer)
        } else if let comment = event.object as? Comment {
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

    func toggleCompleteAction(sender _: Any?, event: FlowEvent) {
        guard let comment = event.object as? Comment, comment.isNote else { return }
        model.run(model.toggleNoteCompleted(note: comment)) { error in
            if error != nil { ToastWindow.shared.showError(text: "Failed to update the comment") }
        }
    }

    func editComment(_ comment: Comment) {
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

    func confirmAndDeleteCollaboration(_ collaboration: Collaboration) {
        ActionSelectorCardViewController(
            icon: nil,
            title: "Are you sure?",
            subtitle: "This collection will be deleted permanently. It can’t be recovered.",
            actions: [
                ActionItem(title: "Delete Collaboration", imageName: "trash", style: .destructive, handler: {
                    self.deleteCollaboration(collaboration)
                }),
                ActionItem(title: "Cancel", imageName: "xmark"),
            ]
        ).installAndShowCard(in: canvasContainer)
    }

    func deleteCollaboration(_ collaboration: Collaboration) {
        // hide the window first so all collaboration change listeners are unregistered
        hideCollaborationWindow(animated: true) {
            // notify the listener about collaboration close (so the pins are updated)
            self.onCollaborationClose?()
            Task {
                do {
                    try await self.model.run(self.model.delete(collaboration: collaboration))
                } catch {
                    Logger.model.error("command error: \(error.localizedDescription, privacy: .public)")
                    ToastWindow.shared.showError(text: "Failed to delete the collaboration")
                }
            }
        }
    }

    func confirmAndDeleteUpload(_ upload: Upload) {
        ActionSelectorCardViewController(
            icon: nil,
            title: "Are you sure?",
            subtitle: "This photo will be deleted permanently. It can’t be recovered.",
            actions: [
                ActionItem(title: "Delete Photo", imageName: "trash", style: .destructive, handler: {
                    self.deleteUpload(upload)
                }),
                ActionItem(title: "Cancel", imageName: "xmark"),
            ]
        ).installAndShowCard(in: canvasContainer)
    }

    func deleteUpload(_ upload: Upload) {
        model.run(model.delete(upload: upload)) { error in
            if error != nil { ToastWindow.shared.showError(text: "Failed to delete the photo") }
        }
    }

    func toggleCollaborationArchived(_ collaboration: Collaboration) {
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
        let commentOrNote = comment.isNote ? "Note" : "Comment"
        ActionSelectorCardViewController(
            icon: nil,
            title: "Are you sure?",
            subtitle: "This \(commentOrNote.lowercased()) will be deleted permanently. It can't be recovered.",
            actions: [
                ActionItem(title: "Delete \(commentOrNote)", imageName: "trash", style: .destructive, handler: {
                    self.deleteComment(comment)
                }),
                ActionItem(title: "Cancel", imageName: "xmark"),
            ]
        ).installAndShowCard(in: canvasContainer)
    }

    func deleteComment(_ comment: Comment) {
        model.run(model.delete(comment: comment)) { error in
            if error != nil {
                ToastWindow.shared.showError(text: "Failed to delete the \(comment.isNote ? "note" : "comment")")
            }
        }
    }
}

// MARK: - running commands

extension CollaborationFlowController {
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
