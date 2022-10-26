import Foundation
import OSLog
import RealmSwift
import UIKit

/// Custom UIEvent sent by views to trigger certain actions defined in `CollaborationFlowActions` and related to given `Object`
/// The way responder chain works forces us to pass objects (Upload, Comment, etc.) as Object as there's no way to use generics
/// to define the custom UIEvent (as they need to later match the signature of action functions which are Objective-C action(sender: Any?, event: UIEvent?)
/// (See "Discussion" in https://developer.apple.com/documentation/uikit/uiapplication/1622946-sendaction)
final class FlowEvent: UIEvent {
    let object: Object
    init(_ object: Object) {
        self.object = object
    }
}

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
}

/// Manages displaying collaboration window
/// This flow controller is a UIViewController to be part of the UI responder chain but its view is a passthrough view so
/// it does not interfere with canvas interactions.
/// All subviews and cards are added to this view controller view.
class CollaborationFlowController: UIViewController {
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
        setupFABs()
    }

    /// Cleanup after showing collaboration windows. The flow controller is not usable after a call to this function
    func stop() {
        removeFABs()
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
            // move collaboration window behind fabs
            view.insertSubview(collaborationVC.view, belowSubview: actionButtons[0])
            collaborationVC.cardDragging?.delegate = self

            // check if already showing, if so then ignore animated and replace instantly
            if self.collaborationVC != nil {
                self.collaborationVC?.cardDragging?.delegate = nil
                let previousCardHeight = self.collaborationVC?.cardDragging?.cardHeight
                hideCollaborationWindow(animated: false)
                setCollaborationHeaderCoverHidden(true, animated: false)
                setFABsHidden(true, animated: false)
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
                self.removeCard(cardViewController: collaborationVC)
            }
            if let scrollView = collaborationVC.drivingScrollView() {
                scrollView.cancelForwardingDelegateInvocations(to: self)
            }
            self.collaborationVC = nil
        }
        setCollaborationHeaderCoverHidden(true, animated: animated)
        setFABsHidden(true, animated: animated)
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

// MARK: FABs (floating action buttons)

extension CollaborationFlowController {
    private func setupFABs() {
        let addPhotosButton = RoundShadowButton(image: UIImage(systemName: "camera") ?? UIImage(), style: .blue)
        addPhotosButton.addTarget(self, action: #selector(addPhotosAction), for: .touchUpInside)
        view.addSubview(addPhotosButton)
        addPhotosButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-12)
        }

        let addAttachmentButton = RoundShadowButton(image: UIImage(systemName: "paperclip") ?? UIImage())
        view.addSubview(addAttachmentButton)
        addAttachmentButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalTo(addPhotosButton.snp.top).offset(-12)
        }

        let addCommentButton = RoundShadowButton(image: UIImage(systemName: "bubble.right") ?? UIImage())
        addCommentButton.addTarget(self, action: #selector(addCommentAction), for: .touchUpInside)
        view.addSubview(addCommentButton)
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

// MARK: - listen to position of collaboration view CTAs

extension CollaborationFlowController: UIScrollViewDelegate {
    /// When the collaboration view content is scrolled we show/hide the FABs based on the current collaboration CTAs position against the header cover
    func scrollViewDidScroll(_: UIScrollView) {
        updateFABsAlpha()
    }

    /// show/hide FABs when the corresponding collaboration view CTAs hide behind the header cover/show again
    private func updateFABsAlpha() {
        guard let collaborationVC = collaborationVC,
              let headerCoverVC = collaborationHeaderCoverVC else { return }

        let ctas: UIView = collaborationVC.detailsVC.ctas

        let headerCoverBottom = headerCoverVC.view.frame.maxY
        let ctasTop = headerCoverVC.view.convert(ctas.frame, from: collaborationVC.detailsVC.view).minY

        // once the collaboration view CTAs get behind the cover let's change the alpha to 1 on the
        // distance equal to ctas height (so the fabs become fully opaque once the ctas are fully hidden)
        let fabsAlpha = max(0, min(1, (headerCoverBottom - ctasTop) / ctas.frame.height))
        actionButtons.forEach { $0.alpha = fabsAlpha }
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
        setFABsHidden(position != .max, animated: true)
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

        updateFABsAlpha()
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
        guard let collaboration = collaboration else { return }

        runCommandsWithProgress(
            commands: model.addComment(
                commentText: addCommentVC.commentText,
                isNote: addCommentVC.isNote,
                toCollaboration: collaboration.id
            ),
            onSuccess: { [weak self] in
                guard let self = self else { return }
                self.lastCancelledCommentText = ""
                addCommentVC.hideCard(animated: true) {
                    self.removeCard(cardViewController: addCommentVC)
                }
            },
            onFailure: { error in
                let alert = UIAlertController(
                    title: "Creating comment error",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                addCommentVC.present(alert, animated: true)
            }
        )
    }
}

// MARK: - edit tags for upload

extension CollaborationFlowController: CollaborationFlowActions {
    func tagsSelectedAction(sender _: Any?, event: FlowEvent) {
        guard let upload = event.object as? Upload else { return }
        let selectedTags = Array(upload.tags.map { TagViewModel(fromTag: $0) })
        let tagsViewModel = TagsViewModel(model: model, initialSelectedTags: selectedTags)
        editTagsVC = SearchAndSelectTagsViewController(tagsViewModel: tagsViewModel)
        editTagsVC!.onClose = { [weak self, weak upload] in
            guard let self = self, let upload = upload else { return }
            self.updateTagsIfChanged(forUpload: upload)
        }
        installCard(
            cardViewController: editTagsVC!,
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
                self.removeCard(cardViewController: editTagsVC)
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
}

// MARK: - name update UI action

extension CollaborationFlowController {
    private func updateName(_ name: String) {
        guard let collaboration = collaboration else { return }
        guard name != collaboration.name else {
            // no change in name, just end editing
            collaborationVC?.view.endEditing(true)
            return
        }

        runCommandsWithProgress(
            commands: model.update(name: name, oldName: collaboration.name, forCollaboration: collaboration.id),
            onSuccess: { [weak self] in
                self?.collaborationVC?.view.endEditing(true)
            },
            onFailure: { error in
                let alert = UIAlertController(
                    title: "Updating name error",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                self.present(alert, animated: true)
            }
        )
    }
}

// MARK: - comment/note actions

extension CollaborationFlowController {
    func moreAction(sender _: Any?, event: FlowEvent) {
        if let comment = event.object as? Comment {
            let commentOrNote = comment.isNote ? "Note" : "Comment"
            ActionSelectorCardViewController(
                icon: UIImage(systemName: "ellipsis"),
                title: "More Menu",
                actions: [
                    ActionItem(title: "Edit \(commentOrNote)", imageName: "pencil", handler: {
                        self.editComment(comment)
                    }),
                    ActionItem(title: "Delete \(commentOrNote)", imageName: "trash", style: .destructive),
                ]
            ).show(in: canvasContainer)
        }
    }

    func toggleCompleteAction(sender _: Any?, event: FlowEvent) {
        guard let comment = event.object as? Comment, comment.isNote else { return }
        Task {
            do {
                try await model.runCommands(model.toggleNoteCompleted(note: comment))
            } catch {
                Logger.model.error("command error: \(error.localizedDescription, privacy: .public)")
            }
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
            guard text != comment.text else { return }
            Task {
                do {
                    try await self.model.runCommands(self.model.update(text: text!, forComment: comment.id))
                } catch {
                    Logger.model.error("command error: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        installCard(
            cardViewController: commentVC,
            cardConfig: CardConfiguration(initialCardPosition: .max, interactive: false, showOverlay: true)
        )
        commentVC.showCard(animated: true)
    }
}

// MARK: - running server side commands

extension CollaborationFlowController {
    /// Shows the activity indicator making the UI not interactive, runs provided commands and runs one of the provided blocks depending
    /// on the success of the commands.
    private func runCommandsWithProgress(commands: [Command],
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
