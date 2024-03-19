import Foundation
import QuickLook
import RealmSwift
import UIKit
import WebKit

/// Implementation of QLPreviewItem - required for previewing items with custom title
class UploadPreviewItem: NSObject, QLPreviewItem {
    var previewItemURL: URL?
    var previewItemTitle: String?
}

/// Fullscreen media view
/// Comprises of 3 parts:
/// 1. header - contains slider view
/// 2. details - implemented in `FullscreenMediaDetailsViewController` - collaboration button, media gallery, author, description, tags
/// 3. comments - implemented in `FeedViewController`
///
/// The details are added as a header for feed table view, so they scroll together with the feed
///
/// ACHTUNG: the gallery in the details can have multiple versions of image Upload (linked by correlation it). So this view can present
/// multiple Uploads. When user selects upload the content of details and comments gets reloaded to show given Upload data.
class FullscreenMediaCardViewController: UIViewController, NonModalCardCoordinating, CardPresentable,
    CardDraggingDelegate
{
    var cardDragging: NonModalCardDragging?
    private var cardDraggingDelegateId: UUID?
    /// This card presents itself in given vc
    private weak var presentingVC: UIViewController?
    /// The view in which it's presented
    private weak var presentingView: UIView?

    private let projectModel: ProjectModel
    unowned let localFiles: LocalFiles
    private let mediaCache: MediaCache
    private let userSettings: UserSettings
    private let showCollaborationButton: Bool
    private var scrollToCommentsInitially: Bool
    unowned let canvasContainer: CanvasContainerViewController

    /// The view containing the slider
    private let headerView = UIView()
    private let headerStroke = UIView()

    enum Mode {
        case summary, comments
    }

    private var detailsVC: FullscreenMediaDetailsViewController!
    private var commentsVC: FeedViewController!

    private var addCommentVC: CommentViewController?
    private let safeAreaCoverView = UIView()
    /// a view below content to cover the space visible when dragging up past the max height
    private(set) var bottomView = UIView()

    private var updatePhotoButton: RoundShadowButton?

    /// Fullscreen media view displays a number of correlated uploads
    private var correlatedUploads: Results<Upload>
    private var uploadsNotificationToken: NotificationToken?
    private let initialUploadIndex: Int

    private var previewItem: UploadPreviewItem?
    private var lastWidth: CGFloat = 0.0

    /// When adding photo version
    var updatePhotoFlow: AddPhotoFlowController?

    /// Initializer
    init(projectModel: ProjectModel,
         localFiles: LocalFiles,
         mediaCache: MediaCache,
         userSettings: UserSettings,
         upload: Upload,
         showCollaborationButton: Bool,
         scrollToCommentsInitially: Bool = false,
         canvasContainer: CanvasContainerViewController)
    {
        self.projectModel = projectModel
        self.localFiles = localFiles
        self.mediaCache = mediaCache
        self.userSettings = userSettings
        correlatedUploads = projectModel.correlatedUploads(upload)
        initialUploadIndex = correlatedUploads.firstIndex(of: upload) ?? 0
        self.showCollaborationButton = showCollaborationButton
        self.scrollToCommentsInitially = scrollToCommentsInitially
        self.canvasContainer = canvasContainer
        super.init(nibName: nil, bundle: nil)

        observeUploads()
    }

    var roundedShadowView: RoundShadowView {
        view as! RoundShadowView
    }

    var containerView: UIView {
        roundedShadowView.containerView
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = RoundShadowView(cornerRadius: 24)
    }

    deinit {
        uploadsNotificationToken?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        containerView.backgroundColor = .dynamic(.Neutral_10)

        setupHeaderView()
        containerView.addSubview(headerView)
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(21)
        }
        headerView.installSliderView()

        setupCommentsVC()
        add(childController: commentsVC)
        containerView.insertSubview(commentsVC.view, belowSubview: headerView)
        commentsVC.view.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        bottomView.backgroundColor = .dynamic(.Neutral_10)
        // added to view (rounded view) as the containerView has a layer mask
        // and bottom view is added outside of its bounds
        view.addSubview(bottomView)
        bottomView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(view.snp.bottom).offset(-1)
            // magic number, just enough so the user won't drag higher than that (beyond the max height)
            make.height.equalTo(500)
        }

        updateColors()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if lastWidth != view.frame.width {
            lastWidth = view.frame.width
            updateCommentsHeaderHeight()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupDetailsVC()

        if scrollToCommentsInitially {
            scrollToCommentsInitially = false
            // give it some time to load and display comments
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.commentsVC.tableView.setContentOffset(
                    CGPoint(x: 0, y: self.commentsVC.tableView.verticalOffsetForBottom), animated: true
                )
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupAddCommentCard()

        if let upload = correlatedUploads.last, upload.isImage, updatePhotoButton == nil {
            updatePhotoButton = RoundShadowButton(
                image: UIImage(systemName: "camera.viewfinder") ?? UIImage(),
                imageTintColor: .white,
                variant: .secondary
            )
            updatePhotoButton?.addTarget(self, action: #selector(updatePhotoAction), for: .touchUpInside)
            view.addSubview(updatePhotoButton!)
            updatePhotoButton!.snp.makeConstraints { make in
                make.trailing.equalToSuperview().inset(22)
                make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom).offset(-22)
            }
        }
    }

    /// updates shadow color based on the interface style and visibility based on the `bottomStrokeVisible`
    private func updateHeaderShadow() {
        guard let scrollView = drivingScrollView() else { return }
        let shadowVisible = scrollView.contentOffset.y > 0
        headerStroke.isHidden = !shadowVisible
        if shadowVisible {
            let darkMode = traitCollection.userInterfaceStyle == .dark
            if darkMode {
                headerView.setShadowWithFigmaValues(x: 0, y: 6, blur: 10, opacity: 0.1)
            } else {
                headerView.setShadowWithFigmaValues(x: 0, y: 3, blur: 6, opacity: 0.1)
            }
            // make the shadow height = 10 points, so the top part of the shadow is not visible
            // (the path covers bottom part of the view only)
            // This only works if the view is actually higher than 10 points. But if it's lower
            // then the shadow with no shadowPath would not be shown (for view that has 0 height)
            // so we still need to "cover" this view from top with another view (in a view that's
            // adding this view controller as a child)
            headerView.layer.shadowPath = UIBezierPath(rect: CGRect(x: 0,
                                                                    y: headerView.bounds.maxY - 10,
                                                                    width: headerView.bounds.width,
                                                                    height: 10)).cgPath
        } else {
            headerView.layer.shadowOpacity = 0
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
            updateHeaderShadow()
        }
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            // animate the card to adjust for the possible height change because of font size change
            guard let cardDragging = cardDragging else { return }
            cardDragging.setPosition(cardDragging.position, withVelocity: 0)
        }
    }

    func updateColors() {
        let darkMode = traitCollection.userInterfaceStyle == .dark
        if darkMode {
            view.setShadowWithFigmaValues(y: -6, blur: 10, opacity: 0.2)
        } else {
            view.setShadowWithFigmaValues(y: -3, blur: 6, opacity: 0.05)
        }
        // stroke not visible in dark mode (same color as background)
        roundedShadowView.topStrokeColor = darkMode ? .Neutral_10 : .Neutral_04
    }

    // MARK: - card presentable

    /// Provide some implementation that returns `nil` so the subclasses can override
    func drivingScrollView() -> UIScrollView? {
        commentsVC.tableView
    }

    // MARK: - card presentation

    /// Convenience function for installing card in given `presentingVC` and showing the card
    @discardableResult func installAndShowCard(
        in presentingVC: UIViewController,
        inView: UIView? = nil,
        showOverlay: Bool = true
    ) -> Self {
        presentingVC.installCard(
            cardViewController: self,
            inView: inView,
            cardConfig: CardConfiguration(initialCardPosition: .max, showOverlay: showOverlay)
        )
        cardDraggingDelegateId = cardDragging?.addDelegate(self)
        showCard(animated: true)
        self.presentingVC = presentingVC
        presentingView = inView ?? presentingVC.view
        return self
    }

    /// Convenience function for hiding the card and removing the card from the presenting view controller
    func dismissCard() {
        safeAreaCoverView.removeFromSuperview()
        if let addCommentVC = addCommentVC {
            addCommentVC.hideCard(animated: false)
            if let presentingVC = presentingVC {
                presentingVC.removeCard(cardViewController: addCommentVC)
            }
        }

        hideCard(animated: true) {
            self.cardDragging?.removeDelegate(self.cardDraggingDelegateId)
            self.presentingVC?.removeCard(cardViewController: self)
            self.presentingVC = nil
            self.presentingView = nil
        }
    }

    // MARK: - dragging delegate to automatically close on overlay tap or minimize

    func cardOverlayTapped() {
        dismissCard()
    }

    func cardWillChangePosition(_ position: CardPosition) {
        if position == .min {
            dismissCard()
        }
    }
}

// MARK: - content height

extension FullscreenMediaCardViewController {
    func height(forContainer _: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .min {
            return 0
        }
        if cardPosition == .medium {
            return -1 // not supported
        }

        // full screen
        return Double.greatestFiniteMagnitude
    }

    /// update the header height based on the details height
    private func updateCommentsHeaderHeight() {
        guard let commentsVC, let detailsVC, detailsVC.view.superview != nil else { return }
        commentsVC.tableView.beginUpdates()
        let tableWidth = commentsVC.view.frame.width
        if tableWidth > 0 {
            commentsVC.tableView.tableHeaderView?.frame.size.width = tableWidth
            detailsVC.view.snp.remakeConstraints { make in
                make.top.leading.trailing.equalToSuperview() // enforce width constraint
                make.bottom.equalToSuperview().priority(.high)
                make.height.greaterThanOrEqualTo(100)
            }
        }
        commentsVC.tableView.tableHeaderView?.frame.size.height = detailsVC.height()
        commentsVC.tableView.endUpdates()
    }
}

// MARK: - content updates

extension FullscreenMediaCardViewController {
    private func observeUploads() {
        uploadsNotificationToken = correlatedUploads
            .observe { [weak self] _ in
                guard let self = self else { return }
                if self.correlatedUploads.isEmpty {
                    if let cardDragging = self.cardDragging, cardDragging.isCardHidden == false {
                        ToastWindow.shared.showWarning(text: "Upload removed")
                    }
                    self.dismissCard()
                }
            }
    }

    private func onCurrentUploadSwitched() {
        if let currentUpload = detailsVC.currentUpload {
            commentsVC.setComments(currentUpload.comments.filter(NSPredicate(value: true)))
            updatePhotoButton?.isHidden = false
        } else {
            commentsVC.hideAllContent()
            updatePhotoButton?.isHidden = true
        }
        // minimize the add comment card when upload switched
        if let cardDragging = addCommentVC?.cardDragging, cardDragging.position == .max {
            addCommentVC?.cardDragging?.setPosition(.medium, withVelocity: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateAddCommentCardVisibility()
        }
    }
}

// MARK: - scrolling

extension FullscreenMediaCardViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_: UIScrollView) {
        updateHeaderShadow()
        updateAddCommentCardVisibility()
    }

    /// Add comment card is only visible if user scrolls to the bottom. Or if user is currently using the card (so it's maximized)
    private func updateAddCommentCardVisibility() {
        guard let addCommentVC, let addCommentCardDragging = addCommentVC.cardDragging else { return }

        // hide if there's no current upload
        guard detailsVC?.currentUpload != nil else {
            addCommentVC.hideCard(animated: true)
            return
        }

        // don't hide if it's in max position
        guard addCommentCardDragging.position != .max else { return }

        if commentsVC.tableView.isAtBottom {
            if addCommentCardDragging.isCardHidden { addCommentVC.showCard(animated: true) }
        } else {
            if !addCommentCardDragging.isCardHidden { addCommentVC.hideCard(animated: true) }
        }
    }

    /// Update the comments bottom inset, so user can scroll to the bottom of coments when "add comment" bar is visible (potentially with keyboard)
    private func updateContentScrollInsets() {
        guard let scrollView = drivingScrollView() else { return }

        var bottomInset = 0.0
        if let addCommentVC {
            // 16 to have some distance between comments and the card
            bottomInset += addCommentVC.height(
                forContainer: view,
                cardPosition: addCommentVC.cardDragging?.position ?? .medium
            )
        }
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        scrollView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
    }
}

// MARK: - setup views

extension FullscreenMediaCardViewController {
    private func setupHeaderView() {
        headerView.backgroundColor = containerView.backgroundColor
        headerView.setContentHuggingPriority(.required, for: .vertical)

        headerStroke.backgroundColor = .dynamic(.Neutral_07)
        headerView.addSubview(headerStroke)
        headerStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
        headerStroke.isHidden = true
    }

    private func setupDetailsVC() {
        guard detailsVC == nil else { return }
        detailsVC = FullscreenMediaDetailsViewController(
            projectModel: projectModel,
            mediaCache: mediaCache,
            correlatedUploads: correlatedUploads,
            initialUploadIndex: initialUploadIndex,
            showCollaborationButton: showCollaborationButton
        )
        detailsVC.onHeightChanged = { [weak self] in
            self?.updateCommentsHeaderHeight()
        }
        detailsVC.onCurrentUploadSwitched = { [weak self] in
            self?.onCurrentUploadSwitched()
        }
        detailsVC.onPhotoSelected = { [weak self] selectedUpload in
            guard let self = self else { return }
            if selectedUpload.isImage {
                // when it's an image then open annotations
                self.showAnnotationsEditor(forUpload: selectedUpload)
            } else {
                // otherwise use the Quick Look Preview
                self.showPreview()
            }
        }
        detailsVC.onAnnotationsSelected = { [weak self] selectedUpload in
            // if annotations are selected we show the same editor as in the photo flow
            self?.showAnnotationsEditor(forUpload: selectedUpload)
        }
        detailsVC.onUpdatePhotoAction = { [weak self] in self?.updatePhotoAction() }
        let header =
            UIView(frame: CGRect(origin: .zero, size: CGSize(width: 1000, height: 1000)))
        header.backgroundColor = containerView.backgroundColor
        commentsVC.add(childController: detailsVC, toView: header)
        detailsVC.view.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.bottom.trailing.equalToSuperview().priority(.high)
            // this is so the autolayout engine doesn't complain when the initial layout is done
            // when the table header view has width and height = 0
            make.width.height.greaterThanOrEqualTo(100)
        }
        commentsVC.tableView.tableHeaderView = header
        updateCommentsHeaderHeight()
    }

    /// Add a CommentViewController card. It'll only be shown when user scrolls to the bottom.
    /// User can start adding new comment by tapping on the text view and making it first responder (then the card will animate to full height)
    private func setupAddCommentCard() {
        guard addCommentVC == nil else { return }
        let addCommentVC = CommentViewController(
            mode: .addComment,
            startEditingWhenShown: false
        )
        addCommentVC.onHeightUpdated = { [weak self] _ in
            self?.updateContentScrollInsets()
        }
        addCommentVC.onCancel = { [weak self] in
            guard let addCommentVC = self?.addCommentVC else { return }
            // clear the text, close keyboard and reset to medium height (so buttons are not visible)
            addCommentVC.commentText = ""
            addCommentVC.view.endEditing(true)
            addCommentVC.cardDragging?.setPosition(.medium, withVelocity: 0, animated: true)
        }
        addCommentVC.onDone = { [weak self] in
            guard let self = self else { return }
            guard let upload = self.detailsVC.currentUpload else { return }
            // save the comment and cleanup the text view (the same as in onCancel)
            self.projectModel.run(
                self.projectModel.addComment(commentText: addCommentVC.commentText, toUpload: upload.id)
            ) { error in
                if error != nil { ToastWindow.shared.showError(text: "Failed to add the comment") }
            }
            addCommentVC.onCancel?()
            // a little later so the comment is already added
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.commentsVC.tableView.setContentOffset(
                    CGPoint(x: 0, y: self.commentsVC.tableView.verticalOffsetForBottom),
                    animated: true
                )
            }
        }

        installCard(
            cardViewController: addCommentVC,
            cardConfig: CardConfiguration(initialCardPosition: .medium, interactive: false, showOverlay: false)
        )
        self.addCommentVC = addCommentVC

        updateContentScrollInsets()
        updateAddCommentCardVisibility()
    }

    /// Show annotations editor for given upload. This is not necessarily the main upload of fullscreen media controller. It might be
    /// one of the correlated uploads (it's the one currently selected in the gallery view)
    private func showAnnotationsEditor(forUpload selectedUpload: Upload) {
        let mediaKey = MediaKey.mediaKey(projectId: projectModel.projectId, upload: selectedUpload, annotated: false)
        let vc = FullscreenImageGalleryViewController(
            imageDataProviderFactory: { [mediaCache] in
                mediaCache.imageProvider(forKey: $0)
            },
            photoKeys: [mediaKey],
            annotations: [selectedUpload.annotations],
            removePhotosEnabled: false
        )
        vc.onCancel = { [weak vc] in
            vc?.dismiss(animated: true)
        }
        vc.onDone = { [weak self, weak vc] _, annotations in
            if let self = self, let annotations = annotations.first {
                self.update(annotations: annotations, forUpload: selectedUpload)
            }
            vc?.dismiss(animated: true)
        }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    private func update(annotations: Annotations?, forUpload selectedUpload: Upload) {
        Task { @MainActor in
            do {
                try await projectModel.run(projectModel.update(annotations: annotations, forUpload: selectedUpload))
            } catch {
                ToastWindow.shared.showError(text: "Failed to update the annotations")
            }
        }
    }

    private func setupCommentsVC() {
        commentsVC = FeedViewController(
            mediaCache: mediaCache,
            projectModel: projectModel,
            comments: (correlatedUploads.first?.comments ?? MutableSet()).filter(NSPredicate(value: true))
        )
        commentsVC.onFeedUpdated = { [weak self] in
            self?.updateAddCommentCardVisibility()
        }
        commentsVC.tableView.backgroundColor = .red
        commentsVC.tableView.contentInsetAdjustmentBehavior = .automatic
        commentsVC.tableView.automaticallyAdjustsScrollIndicatorInsets = true
        commentsVC.tableView.forwardDelegateInvocations(to: self)
    }
}

// MARK: - update photo

extension FullscreenMediaCardViewController {
    @objc private func updatePhotoAction() {
        guard let upload = correlatedUploads.last else { return }
        guard let geometryId = upload.collaboration.first?.feature.first?.geometry.first?.id else {
            // upload collaboration should have a geometry... (this shouldn't really happen)
            return
        }
        updatePhotoFlow = AddPhotoFlowController(
            model: projectModel,
            localFiles: localFiles,
            mediaCache: mediaCache,
            userSettings: userSettings,
            canvasContainer: canvasContainer
        )
        // preselect the geometryId as the update photo flow will not include pin placement
        // (we are adding to this upload collaboratin)
        updatePhotoFlow?.geometryId = geometryId
        // make the new photo version of this upload
        updatePhotoFlow?.correlationId = upload.correlationId
        updatePhotoFlow?.skipPhotoLocationSelection = true
        // multiple photos make no sense for update photo...
        updatePhotoFlow?.allowMultiPhotoSelection = false
        updatePhotoFlow?.onStop = { [weak self] _, _, _ in
            self?.updatePhotoFlow = nil
        }

        // show activity view (a spinner) that covers the screen disabling any user interactions
        let activityView = UIActivityIndicatorView(style: .large)
        activityView.backgroundColor = .black.withAlphaComponent(0.3)
        activityView.color = .Pink_03
        view.addSubview(activityView)
        activityView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        activityView.startAnimating()

        updatePhotoFlow?.start { [weak self] started in
            if !started {
                self?.updatePhotoFlow = nil
            }
        }
        updatePhotoFlow?.onStop = { _, _, _ in
            activityView.removeFromSuperview()
        }
    }
}

extension FullscreenMediaCardViewController: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    /// Shows the media file in Quick Look QLPreviewController
    private func showPreview() {
        Task {
            do {
                guard let upload = correlatedUploads.first else { throw "Upload not found" }
                guard let mediaKey = MediaKey.autoAnnotatedMediaKey(projectId: projectModel.projectId, upload: upload)
                else {
                    throw "Failed to load the file"
                }
                let mediaURL = try await mediaCache.getCachedFileURL(forKey: mediaKey)
                let previewItem = UploadPreviewItem()
                previewItem.previewItemURL = mediaURL
                previewItem.previewItemTitle = upload.fileName
                self.previewItem = previewItem
                DispatchQueue.main.async {
                    let vc = QLPreviewController()
                    vc.dataSource = self
                    vc.delegate = self
                    self.present(vc, animated: true)
                }
            } catch {
                ToastWindow.shared.showError(text: "Failed to load the file")
            }
        }
    }

    func numberOfPreviewItems(in _: QLPreviewController) -> Int {
        previewItem != nil ? 1 : 0
    }

    func previewController(_: QLPreviewController, previewItemAt _: Int) -> QLPreviewItem {
        previewItem!
    }

    func previewController(_: QLPreviewController, transitionViewFor _: QLPreviewItem) -> UIView? {
        // only transition from image gallery, for docs use normal presentation (because the preview
        // doesn't match the target full screen very well, so it doesn't look good)
        detailsVC.galleryVC?.imageViewForCurrentPage
    }
}
