import Foundation
import UIKit

/// Base class for non modal card view controllers that have an icon, a title and a close button at the top.
/// This card only supports .min position (0 height) and .max position.
/// By default this card closes when minimized, when the overlay is tapped or when the close button is tapped
class SheetCardViewController: UIViewController, NonModalCardCoordinating, CardPresentable, CardDraggingDelegate {
    var cardDragging: NonModalCardDragging?
    /// This card presents itself in given vc
    private weak var presentingVC: UIViewController?

    /// The view containing the slider, icon, title, subtitle and close button
    /// It also has some bottom margin added, so any sheet content view can be added directly below it
    let sheetHeaderView = UIView()
    private(set) var closeButton: UIButton!
    private(set) var titleIcon: UIImageView?
    private(set) var titleLabel: UILabel?
    private(set) var subtitleLabel: UILabel?

    /// a view below content to cover the space visible when dragging up past the max height
    private(set) var bottomView = UIView()

    /// Invoked when the sheet is dismissed by tapping close button, the overlay or dragging the card down to min position
    var onCancel: (() -> Void)?

    /// Initializer
    init(icon: UIImage?, title: String?, subtitle: String? = nil, onCancel: (() -> Void)? = nil) {
        super.init(nibName: nil, bundle: nil)

        self.onCancel = onCancel

        if let icon = icon {
            setupTitleIcon(image: icon)
        }
        if let title = title {
            setupTitleLabel(title: title)
        }
        if let subtitle = subtitle {
            setupSubtitleLabel(subtitle: subtitle)
        }
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

        setupSheetHeaderView()
        containerView.addSubview(sheetHeaderView)
        sheetHeaderView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        sheetHeaderView.installSliderView()

        setupCloseButton()
        sheetHeaderView.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.width.height.equalTo(32)
            make.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(21)
            if subtitleLabel == nil {
                make.bottom.equalToSuperview().offset(-16)
            }
        }

        if let titleIcon = titleIcon {
            sheetHeaderView.addSubview(titleIcon)
            titleIcon.snp.makeConstraints { make in
                make.centerY.equalTo(closeButton.snp.centerY)
                make.leading.equalTo(16)
            }
        }
        if let titleLabel = titleLabel {
            sheetHeaderView.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.centerY.equalTo(closeButton.snp.centerY)
                if titleIcon != nil {
                    make.leading.equalTo(titleIcon!.snp.trailing).offset(8)
                } else {
                    make.leading.equalTo(16)
                }
            }
        }
        if let subtitleLabel = subtitleLabel {
            sheetHeaderView.addSubview(subtitleLabel)
            subtitleLabel.snp.makeConstraints { make in
                make.top.equalTo(closeButton.snp.bottom).offset(8)
                make.leading.trailing.equalToSuperview().inset(16)
                make.bottom.equalToSuperview().offset(-16)
            }
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

    // MARK: Views

    private func setupSheetHeaderView() {
        sheetHeaderView.backgroundColor = containerView.backgroundColor
        sheetHeaderView.setContentHuggingPriority(.required, for: .vertical)
    }

    private func setupTitleIcon(image: UIImage) {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .body)
            .applying(UIImage.SymbolConfiguration(weight: .bold))
        titleIcon = UIImageView(image: image.withConfiguration(imageConfig))
        titleIcon!.tintColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
    }

    private func setupTitleLabel(title: String) {
        titleLabel = UILabel()
        titleLabel!.text = title
        titleLabel!.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        titleLabel!.font = UIFont._preferredFont(forTextStyle: .body, symbolicTraits: .traitBold)
        titleLabel!.adjustsFontForContentSizeCategory = true
    }

    private func setupSubtitleLabel(subtitle: String) {
        subtitleLabel = UILabel()
        subtitleLabel!.text = subtitle
        subtitleLabel!.textColor = .dynamic(.Neutral_05)
        subtitleLabel!.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitleLabel!.numberOfLines = 0
        subtitleLabel!.lineBreakMode = .byWordWrapping
        subtitleLabel!.adjustsFontForContentSizeCategory = true
    }

    private func setupCloseButton() {
        closeButton = ButtonWithTapAreaInsets(
            configuration: UIButton.Configuration.closeButton(),
            primaryAction: UIAction(image: UIImage(systemName: "xmark")) { [weak self] _ in
                self?.dismissCard()
                self?.onCancel?()
            }
        )
        .withTapAreaInsets(UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4))
    }

    // MARK: - card presentable

    func height(forContainer containerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .min {
            return 0
        }
        if cardPosition == .medium {
            return -1 // not supported
        }

        view.layoutIfNeeded()
        let height: CGFloat
        if let subtitleLabel = subtitleLabel {
            let fittingSize = CGSize(
                width: containerView.bounds.width - 32,
                height: UIView.layoutFittingCompressedSize.height
            )
            let subtitleHeight = subtitleLabel.systemLayoutSizeFitting(
                fittingSize,
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .defaultLow
            ).height
            height = 61.0 + subtitleHeight + 16.0
        } else {
            height = 69.0
        }
        return height
    }

    /// Provide some implementation that returns `nil` so the subclasses can override
    func drivingScrollView() -> UIScrollView? {
        nil
    }

    // MARK: - card presentation

    /// Convenience function for installing card in given `presentingVC` and showing the card
    @discardableResult func installAndShowCard(in presentingVC: UIViewController, inView: UIView? = nil) -> Self {
        presentingVC.installCard(
            cardViewController: self,
            inView: inView,
            cardConfig: CardConfiguration(initialCardPosition: .max, showOverlay: true)
        )
        cardDragging?.delegate = self
        showCard(animated: true)
        self.presentingVC = presentingVC
        return self
    }

    /// Convenience function for hiding the card and removing the card from the presenting view controller
    func dismissCard() {
        hideCard(animated: true) {
            self.cardDragging?.delegate = nil
            self.presentingVC?.removeCard(cardViewController: self)
            self.presentingVC = nil
        }
    }

    // MARK: - dragging delegate to automatically close on overlay tap or minimize

    func cardOverlayTapped() {
        dismissCard()
        onCancel?()
    }

    func cardWillChangePosition(_ position: CardPosition) {
        if position == .min {
            dismissCard()
            onCancel?()
        }
    }
}
