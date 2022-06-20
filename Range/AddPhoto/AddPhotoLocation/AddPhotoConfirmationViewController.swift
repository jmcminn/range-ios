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

    var roundedShadowView: RoundShadowView {
        view as! RoundShadowView
    }

    var containerView: UIView {
        roundedShadowView.containerView
    }

    override func loadView() {
        view = RoundShadowView(cornerRadius: 24)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        containerView.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)
        updateColors()

        let backButton = UIButton(
            configuration: UIButton.Configuration.bottomBackButton(),
            primaryAction: UIAction(title: "Back") { [weak self] _ in self?.onCancel?() }
        )
        confirmButton = UIButton(
            configuration: UIButton.Configuration.bottomNextButton(),
            primaryAction: UIAction(title: "Confirm") { [weak self] _ in self?.onConfirm?() }
        )
        containerView.addSubview(backButton)
        containerView.addSubview(confirmButton)
        backButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        confirmButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        backButton.snp.makeConstraints { make in
            make.leading.equalTo(16)
            make.top.equalTo(AddPhotoConfirmationViewController.topPadding)
            make.trailing.equalTo(confirmButton.snp.leading).offset(-16)
            make.width.equalTo(confirmButton.snp.width)
        }
        confirmButton.snp.makeConstraints { make in
            make.trailing.equalTo(-16)
            make.top.equalTo(AddPhotoConfirmationViewController.topPadding)
        }
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
