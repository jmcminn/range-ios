import SnapKit
import UIKit

/// View to accept ("Confirm Location") or cancel ("Back") your in-progress photo placement
class AddPhotoConfirmationViewController: UIViewController, NonModalCardCoordinating {
    var cardDragging: NonModalCardDragging?

    static let topPadding = 21.0
    static let bottomPadding = 16.0

    var onBack: (() -> Void)?
    var onDone: (() -> Void)?

    var backButton: UIButton!
    var doneButton: UIButton!

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
        for button in [backButton, doneButton] {
            button?.isUserInteractionEnabled = false
        }
    }

    func setActive() {
        for button in [backButton, doneButton] {
            button?.isUserInteractionEnabled = true
            button?.configuration?.showsActivityIndicator = false
        }
    }

    /// By default a 'done' button is shown. If this flag is switched to `true` it changes the icon and copy to "Next"
    var showNextButton: Bool = false {
        didSet {
            doneButton.setTitle(showNextButton ? String(localized: "Next") : String(localized: "Done"), for: .normal)
            doneButton.setImage(UIImage(systemName: showNextButton ? "arrow.forward" : "checkmark"), for: .normal)
        }
    }

    override func loadView() {
        view = RoundShadowView(cornerRadius: 24)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        containerView.backgroundColor = .dynamic(.Neutral_10)
        updateColors()

        backButton = UIButton(
            configuration: UIButton.Configuration.grayButton(),
            primaryAction: UIAction(title: "Back", image: UIImage(systemName: "arrow.backward")) { [weak self] _ in
                self?.onBack?()
            }
        )
        doneButton = UIButton(
            configuration: UIButton.Configuration.blueButton(),
            primaryAction: UIAction(title: "Done", image: UIImage(systemName: "checkmark")) { [weak self] _ in
                self?.onDone?()
            }
        )
        containerView.addSubview(backButton)
        containerView.addSubview(doneButton)

        backButton.snp.makeConstraints { make in
            make.leading.equalTo(16)
            make.top.equalTo(AddPhotoConfirmationViewController.topPadding)
            make.width.equalToSuperview().multipliedBy(0.5).offset(-24)
        }
        doneButton.snp.makeConstraints { make in
            make.leading.equalTo(backButton.snp.trailing).offset(16)
            make.top.equalTo(AddPinConfirmationViewController.topPadding)
            make.trailing.equalTo(-16)
            make.height.equalTo(backButton)
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
    func height(forContainer _: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .medium {
            return -1 // not supported
        }

        view.layoutIfNeeded()

        return
            AddPhotoConfirmationViewController.topPadding +
            backButton.frame.height +
            AddPhotoConfirmationViewController.bottomPadding
    }
}
