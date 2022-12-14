import Foundation
import RealmSwift
import UIKit

class FullscreenMediaCardViewController: UIViewController, NonModalCardCoordinating, CardPresentable,
    CardDraggingDelegate
{
    var cardDragging: NonModalCardDragging?
    /// This card presents itself in given vc
    private weak var presentingVC: UIViewController?

    /// The view containing the slider, icon, title, subtitle and close button
    /// It also has some bottom margin added, so any sheet content view can be added directly below it
    private let sheetHeaderView = UIView()
    private let avatarView = UIView()
    private let authorLabel = UILabel()
    private let timestampLabel = UILabel()
    private(set) var moreButton: UIButton!
    private(set) var closeButton: UIButton!

    private let tabBar = UITabBar()
    /// a view below content to cover the space visible when dragging up past the max height
    private(set) var bottomView = UIView()

    private let upload: Upload
    private var uploadNotificationToken: NotificationToken?

    /// Initializer
    init(upload: Upload) {
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

        setupSheetHeaderView()
        containerView.addSubview(sheetHeaderView)
        sheetHeaderView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        sheetHeaderView.installSliderView()

        setupHeaderViews()
        setupCloseButton()
        setupMoreButton()

        [avatarView, authorLabel, timestampLabel, moreButton, closeButton].forEach(sheetHeaderView.addSubview)
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
            make.bottom.lessThanOrEqualToSuperview().offset(-16)
        }

        setupTabBar()
        // tab bar is added to view hierarchy on view did appear, because it's added to superview

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
        // Add to this card container view
        let tabBarSuperview = view.superview!
        tabBarSuperview.addSubview(tabBar)
        tabBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(tabBarSuperview.safeAreaLayoutGuide.snp.bottom)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        uploadNotificationToken?.invalidate()
    }

    private func onUploadUpdated() {
        authorLabel.text = upload.author?.displayName
        timestampLabel.text = "(" + Date.formatMediaTitle(upload.timestamp) + ")"
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
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
        nil
    }

    // MARK: - card presentation

    /// Convenience function for installing card in given `presentingVC` and showing the card
    func installAndShowCard(in presentingVC: UIViewController, inView: UIView? = nil, showOverlay: Bool = true) {
        presentingVC.installCard(
            cardViewController: self,
            inView: inView,
            cardConfig: CardConfiguration(initialCardPosition: .max, showOverlay: showOverlay)
        )
        cardDragging?.delegate = self
        showCard(animated: true)
        self.presentingVC = presentingVC
    }

    /// Convenience function for hiding the card and removing the card from the presenting view controller
    func dismissCard() {
//        onDismiss?()
        tabBar.removeFromSuperview()
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

// MARK: - setup views

extension FullscreenMediaCardViewController {
    private func setupSheetHeaderView() {
        sheetHeaderView.backgroundColor = containerView.backgroundColor
        sheetHeaderView.setContentHuggingPriority(.required, for: .vertical)
    }

    private func setupHeaderViews() {
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
    }

    private func setupMoreButton() {
        moreButton = ButtonWithTapAreaInsets(
            configuration: UIButton.Configuration.closeButton(),
            primaryAction: UIAction(image: UIImage(systemName: "ellipsis")) { _ in
                // TODO: 676 more action
//                guard let self = self else { return }
//                UIApplication.shared.sendAction(
//                    #selector(CollaborationFlowActions.moreAction),
//                    to: nil,
//                    from: self,
//                    for: FlowEvent(self.collaboration)
//                )
            }
        )
        .withTapAreaInsets(UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4))
    }

    private func setupCloseButton() {
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
}
