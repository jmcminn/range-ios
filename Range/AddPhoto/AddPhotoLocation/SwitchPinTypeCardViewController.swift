import Foundation
import UIKit

/// Card view controller presenting a segmented control to switch between the Photo Pin and Task Pin
/// To be presented above the confirmation card
class SwitchPinTypeCardViewController: UIViewController, NonModalCardCoordinating {
    var cardDragging: NonModalCardDragging?
    weak var confirmationVC: AddPhotoConfirmationViewController?
    private let availableTypes: [PinTypeOption]
    private let initialType: PinTypeOption
    var onPinTypeChange: ((PinTypeOption) -> Void)?

    private var headerView: UIView!
    private var pinTypeToggle: SegmentedControl!

    private var roundedShadowView: RoundShadowView {
        view as! RoundShadowView
    }

    private var containerView: UIView {
        roundedShadowView.containerView
    }

    /// Initializer
    init(
        availableTypes: [PinTypeOption],
        initialType: PinTypeOption,
        confirmationVC: AddPhotoConfirmationViewController
    ) {
        self.availableTypes = availableTypes
        self.initialType = initialType
        self.confirmationVC = confirmationVC
        super.init(nibName: nil, bundle: nil)
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
        containerView.backgroundColor = .dynamic(.Neutral_09)

        setupHeaderView()
        containerView.addSubview(headerView)
        headerView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(8)
        }

        setupPinTypeToggle()
        containerView.addSubview(pinTypeToggle)
        pinTypeToggle.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(32)
            make.top.equalTo(headerView.snp.bottom).offset(10)
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

    private func updateColors() {
        let darkMode = traitCollection.userInterfaceStyle == .dark
        if darkMode {
            view.setShadowWithFigmaValues(y: -6, blur: 10, opacity: 0.2)
        } else {
            view.setShadowWithFigmaValues(y: -3, blur: 6, opacity: 0.05)
        }
        roundedShadowView.topStrokeColor = darkMode ? .Neutral_07 : .Neutral_04
    }
}

// MARK: - programmatic update of selected option

extension SwitchPinTypeCardViewController {
    /// Select the option in the UI and notify about change
    func selectPinTypeOption(_ option: PinTypeOption, animated: Bool) {
        guard let index = availableTypes.firstIndex(of: option) else { return }
        pinTypeToggle.setSelectedSegmentIndex(index, animated: animated)
        onPinTypeChange?(option)
    }
}

// MARK: - card

extension SwitchPinTypeCardViewController: CardPresentable {
    func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        guard let confirmationVC = confirmationVC else { return 0 }
        view.layoutIfNeeded()

        let cardHeight = 8.0 + headerView.frame.height + 10.0 + pinTypeToggle.frame.height + 16.0

        return confirmationVC.height(forContainer: cardContainerView, cardPosition: cardPosition)
            + cardHeight
    }
}

// MARK: - views

extension SwitchPinTypeCardViewController {
    private func setupHeaderView() {
        let font = UIFont._preferredFont(forTextStyle: .caption2, symbolicTraits: .traitBold)
        let imageConfig = UIImage.SymbolConfiguration(font: font)
        let image = UIImage(systemName: "mappin.and.ellipse", withConfiguration: imageConfig)
        let imageView = UIImageView(image: image)
        imageView.tintColor = .dynamic(.Neutral_04)

        let label = UILabel()
        label.textColor = imageView.tintColor
        label.font = font
        label.adjustsFontForContentSizeCategory = true
        label.text = String(localized: "New Pin Type")

        let imageAndText = UIStackView(arrangedSubviews: [imageView, label])
        imageAndText.axis = .horizontal
        imageAndText.distribution = .equalSpacing
        imageAndText.spacing = 4
        imageAndText.alignment = .trailing

        headerView = imageAndText
    }

    private func setupPinTypeToggle() {
        let actionItems = availableTypes.map { option in
            ActionItem(title: option.uiShortName) { [weak self] in
                self?.onPinTypeChange?(option)
            }
        }
        pinTypeToggle = SegmentedControl(items: actionItems)
        if let index = availableTypes.firstIndex(of: initialType) {
            pinTypeToggle.setSelectedSegmentIndex(index, animated: false)
        }
        pinTypeToggle.backgroundColor = .dynamic(.Neutral_10)
    }
}
