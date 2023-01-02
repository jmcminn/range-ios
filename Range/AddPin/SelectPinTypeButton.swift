import Foundation
import UIKit

/// Button showing image, title and subtitle for given `PinType`
class SelectPinTypeButton: UIControl {
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    init(type: PinType) {
        super.init(frame: .zero)

        if type == .photo {
            imageView.image = UIImage(named: "add_photo_pin")
            titleLabel.text = String(localized: "Photo Pin")
            subtitleLabel.text = String(localized: "Document conditions and progress over time.")
        } else {
            imageView.image = UIImage(named: "add_task_pin")
            titleLabel.text = String(localized: "Task Pin")
            subtitleLabel.text = String(localized: "Assign work to people and monitor progress.")
        }

        setupViews()

        updateColors()
        updateHighlightedColor()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        layer.cornerRadius = 12
        layer.borderWidth = 1

        setupTitleLabel()
        setupSubtitleLabel()

        [imageView, titleLabel, subtitleLabel].forEach(addSubview)
        imageView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(13)
            make.centerX.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(12)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(12)
            make.bottom.equalToSuperview().inset(13)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    override open var isHighlighted: Bool {
        didSet {
            updateHighlightedColor()
        }
    }

    private func updateHighlightedColor() {
        backgroundColor = isHighlighted
            ? .dynamicColor(light: .Neutral_04, dark: .Neutral_07)
            : .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
    }

    private func updateColors() {
        layer.borderColor = chooseColor(light: .Neutral_04, dark: .Neutral_07).cgColor
    }
}

// MARK: - views

extension SelectPinTypeButton {
    private func setupTitleLabel() {
        titleLabel.font = ._preferredFont(forTextStyle: .body, symbolicTraits: .traitBold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        titleLabel.textAlignment = .center
    }

    private func setupSubtitleLabel() {
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_05)
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        subtitleLabel.lineBreakMode = .byWordWrapping
    }
}
