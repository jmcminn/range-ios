import SnapKit
import UIKit

/// View to accept ("Confirm Location") or cancel ("Back") your in-progress photo placement
class AddPhotoConfirmationViewController: UIViewController, NonModalCardCoordinating {
    var cardHandler: NonModalCardHandler?

    static let topPadding = 21.0
    static let bottomPadding = 16.0

    var onCancel: (() -> Void)?
    var onConfirm: (() -> Void)?

    var confirmButton: UIButton!

    var containerView: UIView {
        (view as! RoundShadowView).containerView
    }

    override func loadView() {
        view = RoundShadowView(cornerRadius: 24)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        containerView.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)
        updateShadow()

        containerView.installSliderView()

        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.contentInsets = NSDirectionalEdgeInsets(
            top: 15,
            leading: 28,
            bottom: 15,
            trailing: 28
        )
        buttonConfig.background.cornerRadius = 12

        var backConfig = buttonConfig
        backConfig.baseBackgroundColor = .dynamicColor(light: .Neutral_03, dark: .Neutral_07)
        backConfig.baseForegroundColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)

        var confirmConfig = buttonConfig
        confirmConfig.baseBackgroundColor = .Primary_Blue_04
        confirmConfig.baseForegroundColor = .Neutral_01

        let backButton = UIButton(
            configuration: backConfig,
            primaryAction: UIAction(title: "Back") { [weak self] _ in self?.onCancel?() }
        )
        confirmButton = UIButton(
            configuration: confirmConfig,
            primaryAction: UIAction(title: "Confirm Location") { [weak self] _ in self?.onConfirm?() }
        )
        containerView.addSubview(backButton)
        containerView.addSubview(confirmButton)
        backButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        confirmButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        backButton.snp.makeConstraints { make in
            make.leading.equalTo(16)
            make.top.equalTo(AddPhotoConfirmationViewController.topPadding)
            make.trailing.equalTo(confirmButton.snp.leading).offset(-16)
        }
        confirmButton.snp.makeConstraints { make in
            make.trailing.equalTo(-16)
            make.top.equalTo(AddPhotoConfirmationViewController.topPadding)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateShadow()
        }
    }

    private func updateShadow() {
        let darkMode = traitCollection.userInterfaceStyle == .dark
        view.layer.shadowOpacity = darkMode ? 0.2 : 0.05
        view.layer.shadowColor = UIColor.Shadow.cgColor
    }
}

/// AddPhotoConfirmationViewController is a CardPresentable, but of a fixed size never partially-open
extension AddPhotoConfirmationViewController: CardPresentable {
    func height(forWidth width: CGFloat, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .medium {
            return -1 // not supported
        }

        let fittingSize = CGSize(
            width: width,
            height: UIView.layoutFittingCompressedSize.height
        )

        return
            AddPhotoConfirmationViewController.topPadding +
            confirmButton.systemLayoutSizeFitting(
                fittingSize,
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .defaultLow
            ).height +
            AddPhotoConfirmationViewController.bottomPadding
    }
}
