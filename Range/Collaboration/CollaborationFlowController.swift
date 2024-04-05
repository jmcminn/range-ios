import Foundation
import OSLog
import RealmSwift
import UIKit
import UniformTypeIdentifiers

/// Protocol defining actions that collaboration flow can perform.
/// Required by the views sending actions, so they can use selectors for these functions.
/// See https://swiftrocks.com/understanding-the-ios-responder-chain.html for more info
@objc protocol CollaborationFlowActions: AnyObject {
    /// When "Add photos" button in the Collaboration window header or CTA was tapped
    func addPhotosAction()
    /// When "Add comment" button in the Collaboration window header or CTA was tapped
    func addCommentAction()
    /// When "Add attachment" button in the Collaboration window header or CTA was tapped
    func addAttachmentAction()
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
    unowned let localFiles: LocalFiles
    unowned let mediaCache: MediaCache
    unowned let userSettings: UserSettings
    unowned let canvasContainer: CanvasContainerViewController

    /// callback to notify that collaboration window is closing
    var onCollaborationClose: (() -> Void)?

    /// Currently shown collaboration
    var collaboration: Collaboration?
    /// listen to collaboration removed (but better to geometry as it's reported sooner)
    private var geometryNotificationToken: NotificationToken?
    /// currently shown collaboration window
    var collaborationVC: CollaborationViewController?
    /// the view covering the collaboration window in full screen mode (when the collaboration window card is in max position)
    var collaborationHeaderCoverVC: CollaborationHeaderCoverViewController?
    /// Add comment bottom card - always visible on top of collaboration view
    private var addCommentVC: CommentViewController?

    private var collaborationCardDraggingDelegateId: UUID?

    /// When adding photos from collaboration window
    var addPhotosFlow: AddPhotoFlowController?

    /// Remember the text for the last comment that was cancelled, so when showing the next AddCommentViewController
    /// for the same collaboration use this text. It's reset when the current collaboration changes
    var lastCancelledCommentText: String! = ""

    /// Arbitrary way of deciding whether user is currently editing the collaboration (so in the middle of some meaningful action that should not
    /// be aborted without confirmation)
    var isUserEditingCollaboration: Bool {
        addPhotosFlow != nil // some flow is running
            || view._firstResponder != nil // any field is editing, so user is in the middle of name update for example
    }

    ///
    /// - Parameters:
    ///     - model: - the project model
    ///     - mediaCache: - access to images
    ///     - canvas: - the flow will operate on this canvas
    init(
        model: ProjectModel,
        localFiles: LocalFiles,
        mediaCache: MediaCache,
        userSettings: UserSettings,
        canvasContainer: CanvasContainerViewController
    ) {
        self.model = model
        self.localFiles = localFiles
        self.mediaCache = mediaCache
        self.userSettings = userSettings
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
        collaboration = nil
        geometryNotificationToken?.invalidate()
        geometryNotificationToken = nil
        removeAddCommentCard()
        canvasContainer.remove(childController: self)
    }

    /// Create CollaborationViewController and setup the callbacks
    private func createCollaborationViewController(forCollaboration collaboration: Collaboration)
        -> CollaborationViewController
    {
        let collaborationVC = CollaborationViewController(
            mediaCache: mediaCache,
            projectModel: model,
            collaboration: collaboration
        )
        collaborationVC.onClose = { [weak self] in
            self?.onCollaborationClose?()
        }
        collaborationVC.onNameUpdated = { [weak self] newName in
            self?.updateName(newName)
        }
        return collaborationVC
    }

    /// Finds the first collaboration for this geometry and show its window
    func showCollaborationWindow(forGeometry geometryId: String, animated: Bool) {
        if let geometry = model.mainRealm.object(ofType: Geometry.self, forPrimaryKey: geometryId),
           let feature = geometry.features.first,
           let collaboration = feature.collaborations.first
        {
            showCollaborationWindow(collaboration, animated: animated)
        } else {
            Logger.model.warning("""
                Trying to present collaboration window for geometry
                \(geometryId, privacy: .public) with no collaboration
            """)
        }
    }

    func showCollaborationWindow(_ collaboration: Collaboration, animated: Bool) {
        geometryNotificationToken?.invalidate()
        if let geometry = collaboration.feature.first?.geometry.first {
            geometryNotificationToken = geometry.observe { [weak self] change in
                if case .deleted = change {
                    ToastWindow.shared.showWarning(text: String(localized: "Pin removed"))
                    self?.hideCollaborationWindow(animated: true)
                    self?.onCollaborationClose?()
                }
            }
        }
        let collaborationVC = createCollaborationViewController(forCollaboration: collaboration)

        installCard(
            cardViewController: collaborationVC,
            cardConfig: CardConfiguration(initialCardPosition: .medium, allowsFullScreen: true)
        )
        // move collaboration window behind bottom card
        if let addCommentVC {
            view.insertSubview(collaborationVC.view, belowSubview: addCommentVC.view)
        }

        // check if already showing, if so then ignore animated and replace instantly
        if self.collaborationVC != nil {
            self.collaborationVC?.cardDragging?.removeDelegate(collaborationCardDraggingDelegateId)
            let previousCardHeight = self.collaborationVC?.cardDragging?.cardHeight
            hideCollaborationWindow(animated: false)
            setCollaborationHeaderCoverHidden(true, animated: false)
            // switch to new collaboration after hiding the previous view.
            // We may still want to save some data when closing the collaboration view
            self.collaboration = collaboration
            collaborationCardDraggingDelegateId = collaborationVC.cardDragging?.addDelegate(self)
            collaborationVC.showCard(animated: false)
            if let previousCardHeight = previousCardHeight, let newCardDragging = collaborationVC.cardDragging {
                // animate the height from previous height, so there's no jump
                newCardDragging.setCardHeight(previousCardHeight)
                newCardDragging.setPosition(newCardDragging.position, withVelocity: 0, animated: true)
            }
        } else {
            self.collaboration = collaboration
            collaborationCardDraggingDelegateId = collaborationVC.cardDragging?.addDelegate(self)
            collaborationVC.showCard(animated: animated)
        }
        addCollaborationHeaderCover()
        setupAddCommentCard()
        self.collaborationVC = collaborationVC

        analytics?._trackProjectEvent(name: "collaboration viewed", model, [
            "collaborationType": collaboration.status != nil ? "task" : "photo",
        ])
    }

    /// Hide the currently shown collaboration window (and the header cover)
    func hideCollaborationWindow(animated: Bool, completion: (() -> Void)? = nil) {
        geometryNotificationToken?.invalidate()
        geometryNotificationToken = nil
        if let collaborationVC = collaborationVC {
            collaborationVC.cardDragging?.removeDelegate(collaborationCardDraggingDelegateId)
            collaborationVC.hideCard(animated: animated) {
                self.removeCard(cardViewController: collaborationVC)
                completion?()
            }
            self.collaborationVC = nil
        } else {
            completion?()
        }
        // set collaboration to nil after triggering the hide card. We may still want to save some
        // data when closing the collaboration view
        collaboration = nil
        setCollaborationHeaderCoverHidden(true, animated: animated)
        removeCollaborationHeaderCover()
        removeAddCommentCard()
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
        let collaborationHeaderCoverVC = CollaborationHeaderCoverViewController(
            model: model,
            collaboration: collaboration
        )
        collaborationHeaderCoverVC.onClose = { [weak self] in
            self?.onCollaborationClose?()
        }
        add(childController: collaborationHeaderCoverVC)
        collaborationHeaderCoverVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview()
        }
        collaborationHeaderCoverVC.view.alpha = 0
        // hide temporarily when adding (otherwise it's temporarily visible)
        collaborationHeaderCoverVC.view.isHidden = true
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
            collaborationHeaderCoverVC.view.isHidden = false
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
        collaborationHeaderCoverVC.view.isHidden = false
        collaborationHeaderCoverVC.view.alpha = headerCoverAlpha
    }
}

// MARK: Bottom add comment card

extension CollaborationFlowController {
    /// Add a sticky CommentViewController card.
    /// User can start adding new comment by tapping on the text view and making it first responder (then the card will animate to full height)
    private func setupAddCommentCard() {
        guard addCommentVC == nil else { return }
        let addCommentVC = CommentViewController(
            mode: .add,
            startEditingWhenShown: false
        )
        addCommentVC.onHeightUpdated = { [weak self] _ in
            guard let self else { return }
            self.updateCollaborationWindowOverlapWithAddCommentCard()
            // make the collaboration fullscreen when comment card is expanded
            if let commentCardDragging = addCommentVC.cardDragging, commentCardDragging.position == .max,
               let collaborationVC = self.collaborationVC, let cardDragging = collaborationVC.cardDragging
            {
                if cardDragging.position != .max {
                    cardDragging.setPosition(.max, withVelocity: 0, animated: true)
                }
                let feedScroll = collaborationVC.feedVC.tableView
                feedScroll.setContentOffset(CGPoint(x: 0, y: feedScroll.verticalOffsetForBottom), animated: false)
            }
        }
        addCommentVC.onCancel = { [weak self] in
            guard let addCommentVC = self?.addCommentVC else { return }
            // clear the text, close keyboard and reset to medium height (so buttons are not visible)
            addCommentVC.commentText = ""
            addCommentVC.view.endEditing(true)
            addCommentVC.cardDragging?.setPosition(.medium, withVelocity: 0, animated: true)
        }
        addCommentVC.onDone = { [weak self] in
            guard let self, let collaboration = self.collaboration else { return }
            // save the comment and cleanup the text view (the same as in onCancel)
            self.model.run(
                self.model.addComment(
                    commentText: addCommentVC.commentText,
                    isNote: addCommentVC.isNote,
                    toCollaboration: collaboration.id
                )
            ) { error in
                if error != nil { ToastWindow.shared.showError(text: "Failed to add the comment") }
            }
            addCommentVC.onCancel?()
            // a little later so the comment is already added - scroll to the bottom of the feed to show it
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard let feedScroll = self.collaborationVC?.feedVC.tableView else { return }
                feedScroll.setContentOffset(CGPoint(x: 0, y: feedScroll.verticalOffsetForBottom), animated: false)
            }
        }

        installCard(
            cardViewController: addCommentVC,
            cardConfig: CardConfiguration(
                initialCardPosition: .medium,
                interactive: false,
                showOverlay: .inPosition(.max) // show overlay in max position
            )
        )
        self.addCommentVC = addCommentVC

        addCommentVC.showCard(animated: false)
        DispatchQueue.main.async {
            // small hack, run it in the next main event loop, so it's all layed out already
            self.updateCollaborationWindowOverlapWithAddCommentCard()
        }
    }

    private func removeAddCommentCard() {
        guard let addCommentVC else { return }
        removeCard(cardViewController: addCommentVC)
        self.addCommentVC = nil
    }

    /// Add comment bottom card covers partially the collaboration window - update the feed content inset, so user can actually scroll
    /// to the bottom of it.
    private func updateCollaborationWindowOverlapWithAddCommentCard() {
        guard let addCommentVC, let cardDragging = addCommentVC.cardDragging, let collaborationVC else { return }
        // adjust the collaboration window bottom overlap
        // - safeAreaInsets.bottom = the feed is not covering the bottom safe area while the card height includes it
        collaborationVC.bottomOverlap = max(0, cardDragging.cardHeight - view.safeAreaInsets.bottom)
    }
}

// MARK: - add photos sub flow for current collaboration

extension CollaborationFlowController {
    func addPhotosAction() {
        guard let geometryId = collaboration?.feature.first?.geometry.first?.id else {
            // the collaboration should be selected and have a geometry... (this shouldn't really happen)
            return
        }
        addPhotosFlow = AddPhotoFlowController(
            model: model,
            localFiles: localFiles,
            mediaCache: mediaCache,
            userSettings: userSettings,
            canvasContainer: canvasContainer
        )
        // preselect the geometryId as the add photos flow will not include pin placement
        // (we are adding to the currently showing collaboration window)
        addPhotosFlow?.geometryId = geometryId
        addPhotosFlow?.skipPhotoLocationSelection = true
        addPhotosFlow?.onStop = { [weak self] _, _, _ in
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
            cardConfig: CardConfiguration(initialCardPosition: .max, interactive: false, showOverlay: .always)
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

// MARK: - add attachment to current collaboration

extension CollaborationFlowController: UIDocumentPickerDelegate {
    func addAttachmentAction() {
        var contentTypes = [UTType.jpeg, UTType.png, UTType.pdf]
        if let docxType = UTType(mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document") {
            contentTypes.append(docxType)
        }
        if let xlsxType = UTType(mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") {
            contentTypes.append(xlsxType)
        }
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        documentPicker.delegate = self
        present(documentPicker, animated: true)
    }

    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let collaboration = collaboration else { return }
        guard let url = urls.first else { return }
        guard let fileExtension = url._preferredFilenameExtension(),
              let fileType = Upload.FileType(fromExtension: fileExtension)
        else {
            ToastWindow.shared.showError(text: "File type not supported")
            return
        }
        let fileName = url.deletingPathExtension().lastPathComponent
        Task {
            do {
                let data = try Data(contentsOf: url)
                try await model.run(model.addMedia(data,
                                                   name: fileName,
                                                   fileType: fileType,
                                                   toCollaboration: collaboration))
            } catch {
                Logger.model.error("Adding attachment error \(error.localizedDescription, privacy: .public)")
                ToastWindow.shared.showError(text: "Failed to add the attachment")
            }
        }
    }
}

// MARK: - edit status

extension CollaborationFlowController {
    func editStatusAction() {
        collaborationVC?.view.endEditing(true)
        guard let collaboration = collaboration else { return }
        guard collaboration.status != nil else { return } // not a task
        let statuses = [Status](model.mainRealm.objects(Status.self).sorted(by: Status.uiSortingOrder))
        StatusPickerCardViewController(
            title: "Assign Status",
            statuses: statuses,
            selectedStatus: collaboration.status, onStatusPicked: { [weak self] result in
                guard let self = self else { return }
                switch result {
                case let .status(status):
                    self.updateStatus(status)
                case let .completeAndArchive(status):
                    if model.currentUser.canArchive(collaboration) {
                        self.updateStatusAndArchive(status)
                    } else {
                        self.updateStatus(status)
                    }
                }
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

    private func updateStatusAndArchive(_ status: Status) {
        guard let collaboration = collaboration else { return }
        model.run(model.update(
            status: status,
            forCollaborations: [collaboration.id],
            andArchiveCollaborations: [collaboration.id]
        )) { error in
            if error != nil { ToastWindow.shared.showError(text: "Failed to update the status and archive") }
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
        // make the name first responder, the rest is handled by CollaborationViewController
        // that is a delegate of the text field. So editing the name can also be started directly
        // by tapping on the name view.
        collaborationVC?.nameTextView.becomeFirstResponder()
    }
}

// MARK: - edit name

extension CollaborationFlowController {
    func editDescriptionAction() {
        guard let collaboration = collaboration else { return }
        TextCardViewController(
            title: "Description",
            initialText: collaboration.collaborationDescription,
            placeholderText: "Add a description...",
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
        guard let collaboration = collaboration else { return }
        let viewModel = UsersViewModel(model: model, multiselect: false, showSuspendedUsers: false)
        if let assignee = collaboration.assignee {
            viewModel.addUser(assignee)
            viewModel.set(userWithId: assignee.id, selected: true)
        }
        let userPicker = UserPickerCardViewController(title: "Assignee", viewModel: viewModel)
        if collaboration.assignee != nil {
            // add option to clear current assignee
            userPicker.showNoUserOption = true
        }
        userPicker.onClose = { [weak self] in
            let newAssigneeId = viewModel.selectedUsers.first?.id
            self?.updateAssignee(newAssigneeId)
        }
        userPicker.installAndShowCard(in: self)
    }

    private func updateAssignee(_ assigneeId: String?) {
        guard let collaboration = collaboration else { return }
        model.run(model.update(assigneeId: assigneeId, forCollaboration: collaboration)) { error in
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

// MARK: - note/comment actions

extension CollaborationFlowController {
    func toggleCompleteAction(sender _: Any?, event: FlowEvent) {
        guard let comment = event.object as? Comment, comment.isNote else { return }
        model.run(model.toggleNoteCompleted(note: comment)) { error in
            if error != nil { ToastWindow.shared.showError(text: "Failed to update the comment") }
        }
    }
}
