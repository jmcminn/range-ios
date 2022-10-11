import Foundation
import UIKit

/// Card view controller presenting a titled list of actions
class ActionSelectorCardViewController: UIViewController, NonModalCardCoordinating {
    var cardDragging: NonModalCardDragging?

    private var closeButton: UIButton!
    private var titleIcon: UIImageView?
    private var titleLabel: UILabel?
    private var actionsVC: ActionSelectorViewController!

    // TODO: 305 support for subtitle
    init(icon: UIImage?, title: String?, subtitle _: String? = nil, actions: [ActionItem]) {
        super.init(nibName: nil, bundle: nil)

        if let icon = icon {
            setupTitleIcon(image: icon)
        }
        if let title = title {
            setupTitleLabel(title: title)
        }
        setupActions(actions: actions)
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

        add(childController: actionsVC, toView: containerView)
        actionsVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(closeButton.snp.bottom).offset(16)
            make.bottom.equalToSuperview()
        }

        updateColors()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    private func updateColors() {
        let darkMode = traitCollection.userInterfaceStyle == .dark
        if darkMode {
            view.setShadowWithFigmaValues(y: -6, blur: 10, opacity: 0.2)
        } else {
            view.setShadowWithFigmaValues(y: -3, blur: 6, opacity: 0.05)
        }
        // stroke not visible in dark mode (same color as background)
        roundedShadowView.topStrokeColor = darkMode ? .Neutral_10 : .Neutral_04
    }
}

// MARK: Views

extension ActionSelectorCardViewController {
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

    private func setupCloseButton() {
        closeButton = ButtonWithTapAreaInsets(
            configuration: UIButton.Configuration.closeButton(),
            primaryAction: UIAction(image: UIImage(systemName: "xmark")) { _ in }
        )
        // TODO: 305 handle close
        .withTapAreaInsets(UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4))
    }

    private func setupActions(actions: [ActionItem]) {
        actionsVC = ActionSelectorViewController(actions: actions)
    }
}

extension ActionSelectorCardViewController: CardPresentable {
    func height(forContainer containerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .medium {
            return -1 // not supported
        }

        let fittingSize = CGSize(
            width: containerView.bounds.width,
            height: UIView.layoutFittingCompressedSize.height
        )

        var height = 67.0

        if cardPosition == .max {
            height += (actionsVC.tableView.contentSize.height + 12.0)
        }

        return height
    }

    func drivingScrollView() -> UIScrollView? {
        actionsVC.tableView
    }
}
