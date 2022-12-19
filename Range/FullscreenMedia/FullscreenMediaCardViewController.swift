import Foundation
import RealmSwift
import UIKit

class FullscreenMediaCardViewController: UIViewController, NonModalCardCoordinating, CardPresentable,
    CardDraggingDelegate
{
    var cardDragging: NonModalCardDragging?
    /// This card presents itself in given vc
    private weak var presentingVC: UIViewController?

    private let projectModel: ProjectModel
    private let imageCaches: ImageCaches
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

    private enum Mode {
        case summary, comments
    }

    private var mode = Mode.summary
    private var summaryVC: FullscreenMediaSummaryViewController!
    private var commentsVC: FeedViewController!

    private let tabBar = UITabBar()
    private let safeAreaCoverView = UIView()
    /// a view below content to cover the space visible when dragging up past the max height
    private(set) var bottomView = UIView()

    private let upload: Upload
    private var uploadNotificationToken: NotificationToken?

    /// Initializer
    init(projectModel: ProjectModel,
         imageCaches: ImageCaches,
         upload: Upload,
         showCollaborationButton: Bool)
    {
        self.projectModel = projectModel
        self.imageCaches = imageCaches
        self.showCollaborationButton = showCollaborationButton
        self.upload = upload
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
        containerView.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

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
        if let firstItem = tabBar.items?.first {
            tabBar.selectedItem = firstItem
        }
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
        setMode(.summary)

        bottomView.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        uploadNotificationToken = upload.observe { [weak self] change in
            if case .deleted = change {
                self?.dismissCard()
            } else {
                self?.onUploadUpdated()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        addTabBar()
    }

    /// Add tabBar to this card super view (so it doesn't move with the card and is always at the bottom
    private func addTabBar() {
        let tabBarSuperview = view.superview!
        tabBarSuperview.addSubview(tabBar)
        tabBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(tabBarSuperview.safeAreaLayoutGuide.snp.bottom)
        }
        // we need a view below bottom bar to cover the save area (so the content is not visible below the tab bar)
        safeAreaCoverView.backgroundColor = containerView.backgroundColor
        tabBarSuperview.addSubview(safeAreaCoverView)
        safeAreaCoverView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(tabBar.snp.bottom)
        }

        tabBarSuperview.layoutIfNeeded()
        updateContentScrollInsets()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        uploadNotificationToken?.invalidate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateContentScrollInsets()
    }

    /// Calculate the overlap of tab bar and content scroll and set the content inset for scroll view
    /// This is needed as tab bar is presented on top of the card covering the bottom of the content.
    private func updateContentScrollInsets() {
        guard let tabBarSuperview = tabBar.superview else { return }
        let tabBarFrame = tabBar.frame
        // already layed out?
        guard tabBarFrame.height > 0 else { return }
        let containerFrame = containerView.convert(containerView.bounds, to: tabBarSuperview)
        let overlap = containerFrame.maxY - tabBarFrame.minY

        // +16 to have some margin at the bottom
        let contentInset = UIEdgeInsets(top: 0, left: 0, bottom: overlap + 16, right: 0)
        // for scroll indicator there's no need to add 16, let it extend until the tab bar
        let scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: overlap, right: 0)
        summaryVC.scrollView.contentInset = contentInset
        summaryVC.scrollView.scrollIndicatorInsets = scrollIndicatorInsets
        commentsVC.tableView.contentInset = contentInset
        commentsVC.tableView.scrollIndicatorInsets = scrollIndicatorInsets
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
        timestampLabel.text = "(" + Date.formatMediaTitle(upload.timestamp) + ")"
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
        cardDragging?.delegate = self
        showCard(animated: true)
        self.presentingVC = presentingVC
        return self
    }

    /// Convenience function for hiding the card and removing the card from the presenting view controller
    func dismissCard() {
        tabBar.removeFromSuperview()
        safeAreaCoverView.removeFromSuperview()
        hideCard(animated: true) {
            self.cardDragging?.delegate = nil
            self.presentingVC?.removeCard(cardViewController: self)
            self.presentingVC = nil
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

        updateHeaderShadow()

        if let cardDragging = cardDragging {
            // reset scroll view listeners
            cardDragging.remove()
            cardDragging.install()
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

        headerStroke.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)
        headerView.addSubview(headerStroke)
        headerStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
        headerStroke.isHidden = true

        avatarView.layer.cornerRadius = 16
        avatarView.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)

        authorLabel.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        authorLabel.font = ._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold)
        authorLabel.adjustsFontForContentSizeCategory = true
        authorLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        timestampLabel.textColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_05)
        timestampLabel.font = ._preferredFont(forTextStyle: .caption2, symbolicTraits: .traitBold)
        timestampLabel.adjustsFontForContentSizeCategory = true
        timestampLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        moreButton = ButtonWithTapAreaInsets(
            configuration: UIButton.Configuration.closeButton(),
            primaryAction: UIAction(image: UIImage(systemName: "ellipsis")) { [weak self] _ in
                guard let self = self else { return }
                UIApplication.shared.sendAction(
                    #selector(ProjectFlowController.moreAction), to: nil, from: self,
                    for: FlowEvent(self.upload)
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
        tabBar.items = [
            UITabBarItem(
                title: String(localized: "Summary"), image: UIImage(systemName: "info.circle"), tag: 0
            ),
            UITabBarItem(
                title: String(localized: "Comments"), image: UIImage(systemName: "bubble.right"), tag: 1
            ),
        ]
        tabBar.delegate = self
        // to hide the default top stroke for tab bar:
        tabBar.clipsToBounds = true
        // HACK - add separator to tab bar (maybe not even a hack??)
        let separator = UIView()
        separator.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)
        tabBar.addSubview(separator)
        separator.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
    }

    private func setupSummaryVC() {
        summaryVC = FullscreenMediaSummaryViewController(
            projectModel: projectModel,
            imageCaches: imageCaches,
            upload: upload,
            showCollaborationButton: showCollaborationButton
        )
        summaryVC.scrollView.contentInsetAdjustmentBehavior = .never
        summaryVC.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        summaryVC.scrollView.delegate = self
    }

    private func setupCommentsVC() {
        commentsVC = FeedViewController(
            imageCaches: imageCaches,
            projectModel: projectModel,
            comments: upload.comments.filter(NSPredicate(value: true))
        )
        commentsVC.tableView.contentInsetAdjustmentBehavior = .never
        commentsVC.tableView.automaticallyAdjustsScrollIndicatorInsets = false
        commentsVC.tableView.forwardDelegateInvocations(to: self)
    }
}
