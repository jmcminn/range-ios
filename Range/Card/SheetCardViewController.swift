import Foundation
import UIKit

/// Base class for non modal card view controllers that have an icon, a title and a close button at the top.
/// This card only supports .min position (0 height) and .max position.
/// By default this card closes when minimized, when the overlay is tapped or when the close button is tapped
class SheetCardViewController: UIViewController, NonModalCardCoordinating, CardPresentable, CardDraggingDelegate {
    var cardDragging: NonModalCardDragging?
    /// This card presents itself in given vc
    private weak var presentingVC: UIViewController?

    private(set) var closeButton: UIButton!
    private(set) var titleIcon: UIImageView?
    private(set) var titleLabel: UILabel?
    private(set) var subtitleLabel: UILabel?

    /// Invoked when the sheet will be dismissed
    var onDismiss: (() -> Void)?

    /// Initializer
    init(icon: UIImage?, title: String?, subtitle: String? = nil, onDismiss: (() -> Void)? = nil) {
        super.init(nibName: nil, bundle: nil)

        self.onDismiss = onDismiss

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
        containerView.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        containerView.installSliderView()

        setupCloseButton()
        containerView.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.width.height.equalTo(32)
            make.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(21)
        }

        if let titleIcon = titleIcon {
            containerView.addSubview(titleIcon)
            titleIcon.snp.makeConstraints { make in
                make.centerY.equalTo(closeButton.snp.centerY)
                make.leading.equalTo(16)
            }
        }
        if let titleLabel = titleLabel {
            containerView.addSubview(titleLabel)
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
            containerView.addSubview(subtitleLabel)
            subtitleLabel.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(59)
                make.leading.trailing.equalToSuperview().inset(16)
            }
        }

        updateColors()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
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
        subtitleLabel!.textColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_05)
        subtitleLabel!.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitleLabel!.numberOfLines = 0
        subtitleLabel!.lineBreakMode = .byWordWrapping
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

    // MARK: - card presentable

    func height(forContainer containerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .min {
            return 0
        }
        if cardPosition == .medium {
            return -1 // not supported
        }

        let height: CGFloat
        if let subtitleLabel = subtitleLabel {
            let fittingSize = CGSize(
                width: containerView.bounds.width,
                height: UIView.layoutFittingCompressedSize.height
            )
            let subtitleHeight = subtitleLabel.systemLayoutSizeFitting(
                fittingSize,
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .defaultLow
            ).height
            height = 59.0 + subtitleHeight + 16.0
        } else {
            height = 67.0
        }
        return height
    }

    // MARK: - card presentation

    /// Convenience function for installing card in given `presentingVC` and showing the card
    func installAndShowCard(in presentingVC: UIViewController) {
        presentingVC.installCard(
            cardViewController: self,
            cardConfig: CardConfiguration(initialCardPosition: .max, showOverlay: true)
        )
        cardDragging?.delegate = self
        showCard(animated: true)
        self.presentingVC = presentingVC
    }

    /// Convenience function for hiding the card and removing the card from the presenting view controller
    func dismissCard() {
        onDismiss?()
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
