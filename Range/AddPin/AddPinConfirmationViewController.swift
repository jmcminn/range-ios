import SnapKit
import UIKit

/// View to accept ("Confirm Location") or cancel the placement of new pin
class AddPinConfirmationViewController: UIViewController, NonModalCardCoordinating {
    var cardDragging: NonModalCardDragging?

    static let topPadding = 21.0
    static let bottomPadding = 16.0

    var onCancel: (() -> Void)?
    var onConfirm: (() -> Void)?

    var cancelButton: UIButton!
    var confirmButton: UIButton!

    var roundedShadowView: RoundShadowView {
        view as! RoundShadowView
    }

    var containerView: UIView {
        roundedShadowView.containerView
    }

    var showDarkBorder: Bool = false {
        didSet {
            updateColors()
        }
    }

    override func loadView() {
        view = RoundShadowView(cornerRadius: 24)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        containerView.backgroundColor = .dynamic(.Neutral_10)
        updateColors()

        cancelButton = UIButton(
            configuration: UIButton.Configuration.grayButton(),
            primaryAction: UIAction(title: String(localized: "Cancel")) { [weak self] _ in self?.onCancel?() }
        )
        confirmButton = UIButton(
            configuration: UIButton.Configuration.blueButton(imagePlacement: .leading),
            primaryAction: UIAction(title: String(localized: "Confirm Location")) { [weak self] _ in
                self?.onConfirm?()
            }
        )
        containerView.addSubview(cancelButton)
        containerView.addSubview(confirmButton)
        cancelButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        cancelButton.snp.makeConstraints { make in
            make.leading.equalTo(16)
            make.top.equalTo(AddPinConfirmationViewController.topPadding)
            make.width.equalToSuperview().multipliedBy(0.5).offset(-24)
        }
        confirmButton.snp.makeConstraints { make in
            make.leading.equalTo(cancelButton.snp.trailing).offset(16)
            make.top.equalTo(AddPinConfirmationViewController.topPadding)
            make.trailing.equalTo(-16)
            make.height.equalTo(cancelButton)
        }
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

    private func updateColors() {
        let darkMode = traitCollection.userInterfaceStyle == .dark
        if darkMode {
            view.setShadowWithFigmaValues(y: -6, blur: 10, opacity: 0.2)
        } else {
            view.setShadowWithFigmaValues(y: -3, blur: 6, opacity: 0.05)
        }
        // stroke visibility in dark mode depends on showDarkBorder (if false same color as background)
        roundedShadowView.topStrokeColor = darkMode
            ? (showDarkBorder ? .Neutral_07 : .Neutral_10)
            : .Neutral_04
    }
}

/// AddPhotoConfirmationViewController is a CardPresentable, but of a fixed size never partially-open
extension AddPinConfirmationViewController: CardPresentable {
    func height(forContainer _: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .medium {
            return -1 // not supported
        }

        view.layoutIfNeeded()

        return
            AddPhotoConfirmationViewController.topPadding +
            cancelButton.frame.height +
            AddPhotoConfirmationViewController.bottomPadding
    }
}
