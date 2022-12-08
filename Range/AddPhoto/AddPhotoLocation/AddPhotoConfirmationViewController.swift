import SnapKit
import UIKit

/// View to accept ("Confirm Location") or cancel ("Back") your in-progress photo placement
class AddPhotoConfirmationViewController: UIViewController, NonModalCardCoordinating {
    var cardDragging: NonModalCardDragging?

    static let topPadding = 21.0
    static let bottomPadding = 16.0

    var onCancel: (() -> Void)?
    var onDone: (() -> Void)?
    var onContinue: (() -> Void)?

    var backButton: UIButton!
    var doneButton: UIButton!
    var continueButton: UIButton!

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

    func setInactiveWithActivityIndicator(on button: UIButton) {
        button.configuration?.showsActivityIndicator = true
        for button in [backButton, doneButton, continueButton] {
            button?.isUserInteractionEnabled = false
        }
    }

    func setActive() {
        for button in [backButton, doneButton, continueButton] {
            button?.isUserInteractionEnabled = true
            button?.configuration?.showsActivityIndicator = false
        }
    }

    override func loadView() {
        view = RoundShadowView(cornerRadius: 24)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        containerView.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)
        updateColors()

        backButton = UIButton(
            configuration: UIButton.Configuration.grayButton(),
            primaryAction: UIAction(image: UIImage(systemName: "arrow.backward")) { [weak self] _ in self?.onCancel?() }
        )
        doneButton = UIButton(
            configuration: UIButton.Configuration.blueButton(imagePlacement: .leading),
            primaryAction: UIAction(title: "Done", image: UIImage(systemName: "checkmark")) { [weak self] _ in
                self?.onDone?()
            }
        )
        continueButton = UIButton(
            configuration: UIButton.Configuration.blueButton(imagePlacement: .leading),
            primaryAction: UIAction(title: "Continue", image: UIImage(systemName: "camera")) { [weak self] _ in
                self?.onContinue?()
            }
        )
        containerView.addSubview(backButton)
        containerView.addSubview(doneButton)
        containerView.addSubview(continueButton)
        backButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        backButton.snp.makeConstraints { make in
            make.leading.equalTo(16)
            make.top.equalTo(AddPhotoConfirmationViewController.topPadding)
            make.trailing.equalTo(doneButton.snp.leading).offset(-16)
            make.width.equalTo(48)
            make.height.equalTo(continueButton)
        }
        doneButton.snp.makeConstraints { make in
            make.leading.equalTo(backButton.snp.trailing).offset(16)
            make.trailing.equalTo(continueButton.snp.leading).offset(-16)
            make.top.equalTo(AddPhotoConfirmationViewController.topPadding)
            make.width.equalTo(continueButton.snp.width)
            make.height.equalTo(continueButton)
        }
        continueButton.snp.makeConstraints { make in
            make.trailing.equalTo(-16)
            make.top.equalTo(AddPhotoConfirmationViewController.topPadding)
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
extension AddPhotoConfirmationViewController: CardPresentable {
    func height(forContainer containerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .medium {
            return -1 // not supported
        }

        view.layoutIfNeeded()
        let fittingSize = CGSize(
            width: containerView.bounds.width,
            height: UIView.layoutFittingCompressedSize.height
        )

        return
            AddPhotoConfirmationViewController.topPadding +
            continueButton.systemLayoutSizeFitting(
                fittingSize,
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .defaultLow
            ).height +
            AddPhotoConfirmationViewController.bottomPadding
    }
}
