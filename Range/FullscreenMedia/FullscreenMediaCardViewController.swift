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
    private let mediaCache: MediaCache
    private let showCollaborationButton: Bool

    /// The view containing the slider, icon, title, subtitle and close button
    /// It also has some bottom margin added, so any sheet content view can be added directly below it
    private let headerView = UIView()
    private let headerStroke = UIView()
    private let avatarView = UIView()
    private let authorLabel = UILabel()
    private let timestampLabel = UILabel()
    private var moreButton: UIButton!
    private var closeButton: UIButton!

    enum Mode {
        case summary, comments
    }

    private let initialMode: Mode
    private var mode = Mode.summary
    private var summaryVC: FullscreenMediaSummaryViewController!
    private var commentsVC: FeedViewController!
    // shown when there's no comments in the feed
    private let noCommentsView = UIView()

    private let tabBar = UITabBar()
    private var addCommentVC: CommentViewController?
    private let safeAreaCoverView = UIView()
    /// a view below content to cover the space visible when dragging up past the max height
    private(set) var bottomView = UIView()

    let upload: Upload
    private var uploadNotificationToken: NotificationToken?

    private var previewItem: UploadPreviewItem?

    /// Initializer
    init(projectModel: ProjectModel,
         mediaCache: MediaCache,
         upload: Upload,
         showCollaborationButton: Bool,
         initialMode: Mode = .summary)
    {
        self.projectModel = projectModel
        self.mediaCache = mediaCache
        self.showCollaborationButton = showCollaborationButton
        self.upload = upload
        self.initialMode = initialMode
        super.init(nibName: nil, bundle: nil)

        onUploadUpdated()
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

    override func viewDidLoad() {
        super.viewDidLoad()
        containerView.backgroundColor = .dynamic(.Neutral_10)

        setupHeaderView()
        containerView.addSubview(headerView)
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        headerView.installSliderView()

        [avatarView, authorLabel, timestampLabel, moreButton, closeButton].forEach(headerView.addSubview)
        avatarView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(21)
            make.width.height.equalTo(32)
            make.leading.equalToSuperview().inset(16)
        }
        authorLabel.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview().offset(21)
            make.leading.equalTo(avatarView.snp.trailing).offset(8)
            make.trailing.equalTo(moreButton.snp.leading).offset(-8)
            make.bottom.equalTo(avatarView.snp.centerY).priority(.high)
        }
        timestampLabel.snp.makeConstraints { make in
            make.top.equalTo(authorLabel.snp.bottom)
            make.leading.trailing.equalTo(authorLabel)
            make.bottom.lessThanOrEqualToSuperview().offset(-16)
        }
        moreButton.snp.makeConstraints { make in
            make.width.height.top.equalTo(avatarView)
            make.trailing.equalTo(closeButton.snp.leading).offset(-8)
        }
        closeButton.snp.makeConstraints { make in
            make.top.width.height.equalTo(avatarView)
            make.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-16).priority(.high)
        }

        setupTabBar()
        // tab bar is added to view hierarchy on view did appear, because it's added to superview

        setupSummaryVC()
        add(childController: summaryVC)
        containerView.insertSubview(summaryVC.view, belowSubview: headerView)
        summaryVC.view.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        setupCommentsVC()
        add(childController: commentsVC)
        containerView.insertSubview(commentsVC.view, belowSubview: headerView)
        commentsVC.view.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        setupNoCommentsView()
        commentsVC.view.addSubview(noCommentsView)
        noCommentsView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        setMode(initialMode)

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

        uploadNotificationToken = upload.observe { [weak self] change in
            if case .deleted = change {
                if let cardDragging = self?.cardDragging, cardDragging.isCardHidden == false {
                    ToastWindow.shared.showWarning(text: "Upload removed")
                }
                self?.dismissCard()
            } else {
                self?.onUploadUpdated()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        addTabBar()
        addCommentBar()
    }

    /// Add tabBar to this card super view (so it doesn't move with the card and is always at the bottom
    private func addTabBar() {
        guard let presentingView = presentingView else {
            return
        }
        presentingView.addSubview(tabBar)
        tabBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(presentingView.safeAreaLayoutGuide.snp.bottom)
        }
        // we need a view below bottom bar to cover the save area (so the content is not visible below the tab bar)
        safeAreaCoverView.backgroundColor = containerView.backgroundColor
        presentingView.addSubview(safeAreaCoverView)
        safeAreaCoverView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(tabBar.snp.bottom)
        }

        presentingView.layoutIfNeeded()
        updateSummaryContentScrollInsets()
    }

    /// Add a CommentViewController behind the tab bar so the text view is visible and user can start adding new comment
    /// by tapping on the text view and making it first responder (then the card will animate to full height)
    private func addCommentBar() {
        guard let presentingVC = presentingVC, let presentingView = presentingView else {
            return
        }
        let addCommentVC = CommentViewController(
            mode: .addComment,
            startEditingWhenShown: false,
            shownAboveView: tabBar
        )
        addCommentVC.onHeightUpdated = { [weak self] _ in
            self?.updateCommentsContentScrollInsets()
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
            // save the comment and cleanup the text view (the same as in onCancel)
            self.projectModel.run(
                self.projectModel.addComment(commentText: addCommentVC.commentText, toUpload: self.upload.id)
            ) { error in
                if error != nil { ToastWindow.shared.showError(text: "Failed to add the comment") }
            }
            addCommentVC.onCancel?()
        }

        presentingVC.installCard(
            cardViewController: addCommentVC,
            inView: presentingView,
            cardConfig: CardConfiguration(initialCardPosition: .medium, interactive: false, showOverlay: false)
        )
        // we want it behind the tab bar
        presentingView.insertSubview(addCommentVC.view, belowSubview: tabBar)
        addCommentVC.showCard(animated: true)
        addCommentVC.view.isHidden = mode == .summary
        self.addCommentVC = addCommentVC

        presentingView.layoutIfNeeded()
        updateCommentsContentScrollInsets()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateSummaryContentScrollInsets()
        updateCommentsContentScrollInsets()
    }

    /// Calculate the overlap of tab bar and content scroll and set the content inset for summary scroll view.
    /// This is needed as tab bar is presented on top of the card covering the bottom of the content.
    private func updateSummaryContentScrollInsets() {
        guard let presentingView = presentingView else { return }
        let containerFrame = containerView.convert(containerView.bounds, to: presentingView)
        // already layed out?
        guard tabBar.frame.height > 0 else { return }
        let tabBarOverlap = containerFrame.maxY - tabBar.frame.minY
        // +16 to have some margin at the bottom
        summaryVC.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: tabBarOverlap + 16, right: 0)
        summaryVC.scrollView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: tabBarOverlap, right: 0)
    }

    /// Similar to `updateSummaryContentScrollInsets` It updates the content inset for comments, in this case it's based on the addCommentVC height
    private func updateCommentsContentScrollInsets() {
        guard let presentingView = presentingView else { return }
        let containerFrame = containerView.convert(containerView.bounds, to: presentingView)

        guard let addCommentVC = addCommentVC, addCommentVC.view.frame.height > 0 else { return }
        let addCommentOverlap = containerFrame.maxY - addCommentVC.view.frame.minY
        commentsVC.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: addCommentOverlap, right: 0)
        commentsVC.tableView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: addCommentOverlap, right: 0)

        noCommentsView.snp.updateConstraints { make in
            make.centerY.equalToSuperview().offset(-addCommentOverlap / 2)
        }
    }

    /// updates shadow color based on the interface style and visibility based on the `bottomStrokeVisible`
    private func updateHeaderShadow() {
        guard let scrollView = drivingScrollView() else { return }
        let shadowVisible = scrollView.contentOffset.y > 0
        // always show for .comments
        headerStroke.isHidden = mode == .summary && !shadowVisible
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

    private func onUploadUpdated() {
        authorLabel.text = upload.author?.displayName
        timestampLabel.text = Date.format1(upload.timestamp)
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

    /// Provide some implementation that returns `nil` so the subclasses can override
    func drivingScrollView() -> UIScrollView? {
        mode == .summary ? summaryVC.scrollView : commentsVC.tableView
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
        uploadNotificationToken?.invalidate()
        uploadNotificationToken = nil
        tabBar.removeFromSuperview()
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

// MARK: - tab switching

extension FullscreenMediaCardViewController: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        let mode: Mode = item == tabBar.items?[0] ? .summary : .comments
        if mode != self.mode {
            setMode(mode)
        }
    }

    /// set summary or comments
    private func setMode(_ mode: Mode) {
        self.mode = mode

        summaryVC.view.isHidden = mode == .comments
        commentsVC.view.isHidden = mode == .summary
        addCommentVC?.view.isHidden = mode == .summary

        updateHeaderShadow()

        if let cardDragging = cardDragging {
            // reset scroll view listeners
            cardDragging.reloadScrollViewDelegate()
        }
    }
}

// MARK: - content scroll delegate

extension FullscreenMediaCardViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_: UIScrollView) {
        updateHeaderShadow()
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

        avatarView.layer.cornerRadius = 16
        avatarView.backgroundColor = .dynamic(.Neutral_07)

        authorLabel.textColor = .dynamic(.Neutral_04)
        authorLabel.font = ._preferredFont(forTextStyle: .callout, symbolicTraits: .traitBold)
        authorLabel.adjustsFontForContentSizeCategory = true
        authorLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        timestampLabel.textColor = .dynamic(.Neutral_05)
        timestampLabel.font = .preferredFont(forTextStyle: .footnote)
        timestampLabel.adjustsFontForContentSizeCategory = true
        timestampLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        moreButton = ButtonWithTapAreaInsets(
            configuration: UIButton.Configuration.closeButton(),
            primaryAction: UIAction(image: UIImage(systemName: "ellipsis")) { [weak self] _ in
                guard let self = self else { return }
                UIApplication.shared.sendAction(
                    #selector(ProjectFlowController.moreAction), to: nil, from: self,
                    for: FlowEvent(self.upload, sourceView: self.moreButton)
                )
            }
        )
        .withTapAreaInsets(UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4))

        closeButton = ButtonWithTapAreaInsets(
            configuration: UIButton.Configuration.closeButton(),
            primaryAction: UIAction(image: UIImage(systemName: "xmark")) { [weak self] _ in
                self?.dismissCard()
            }
        )
        .withTapAreaInsets(UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4))
    }

    private func setupTabBar() {
        let items = [
            UITabBarItem(
                title: String(localized: "Summary"), image: UIImage(systemName: "info.circle"), tag: 0
            ),
            UITabBarItem(
                title: String(localized: "Comments"), image: UIImage(systemName: "bubble.right"), tag: 1
            ),
        ]
        tabBar.items = items
        if initialMode == .summary {
            tabBar.selectedItem = items[0]
        } else {
            tabBar.selectedItem = items[1]
        }
        tabBar.delegate = self
        // to hide the default top stroke for tab bar:
        tabBar.clipsToBounds = true
        // HACK - add separator to tab bar (maybe not even a hack??)
        let separator = UIView()
        separator.backgroundColor = .dynamic(.Neutral_07)
        tabBar.addSubview(separator)
        separator.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
    }

    private func setupSummaryVC() {
        summaryVC = FullscreenMediaSummaryViewController(
            projectModel: projectModel,
            mediaCache: mediaCache,
            upload: upload,
            showCollaborationButton: showCollaborationButton
        )
        summaryVC.scrollView.contentInsetAdjustmentBehavior = .never
        summaryVC.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        summaryVC.scrollView.delegate = self
        summaryVC.onPhotoSelected = { [weak self] in
            // when photo is selected we show the iOS provided preview
            self?.showPreview()
        }
        summaryVC.onAnnotationsSelected = { [weak self] in
            // if annotations are selected we show the same editor as in the photo flow
            self?.showAnnotationsEditor()
        }
    }

    private func showAnnotationsEditor() {
        let mediaKey = MediaKey(projectId: projectModel.projectId, upload: upload)
        let vc = FullscreenImageGalleryViewController(
            imageDataProviderFactory: { [mediaCache] in
                mediaCache.imageProvider(forKey: $0)
            },
            photoKeys: [mediaKey],
            removePhotoHandler: nil
        )
        vc.onDone = { [weak vc] in
            vc?.dismiss(animated: true)
        }
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    private func setupCommentsVC() {
        commentsVC = FeedViewController(
            mediaCache: mediaCache,
            projectModel: projectModel,
            comments: upload.comments.filter(NSPredicate(value: true))
        )
        commentsVC.tableView.contentInsetAdjustmentBehavior = .never
        commentsVC.tableView.automaticallyAdjustsScrollIndicatorInsets = false
        commentsVC.tableView.forwardDelegateInvocations(to: self)
    }

    private func setupNoCommentsView() {
        let image = UIImageView(image: UIImage(named: "comments"))
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .dynamic(.Neutral_05)
        label.adjustsFontForContentSizeCategory = true
        label.text = String(localized: "There are no comments...")
        noCommentsView.addSubview(image)
        image.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
        }
        noCommentsView.addSubview(label)
        label.snp.makeConstraints { make in
            make.top.equalTo(image.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview()
        }
        commentsVC.onFeedUpdated = { [weak self] in
            guard let self = self else { return }
            self.noCommentsView.isHidden = !self.commentsVC.items.isEmpty
        }
    }
}

extension FullscreenMediaCardViewController: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    /// Shows the media file in Quick Look QLPreviewController
    private func showPreview() {
        Task {
            do {
                let mediaURL = try await mediaCache
                    .getCachedFileURL(forKey: MediaKey(projectId: projectModel.projectId, upload: upload))
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
        summaryVC.galleryVC?.imageViewForCurrentPage
    }
}
