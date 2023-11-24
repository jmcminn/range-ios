import Foundation
import UIKit

/// Button showing image, title and subtitle for given `PinType`
class SelectPinTypeButton: UIControl {
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    init(type: PinTypeOption) {
        super.init(frame: .zero)

        imageView.image = UIImage(named: type.uiImageName)
        titleLabel.text = type.uiLongName
        subtitleLabel.text = type.uiDescription

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

        setupImageView()
        setupTitleLabel()
        setupSubtitleLabel()

        [imageView, titleLabel, subtitleLabel].forEach(addSubview)
        imageView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(13)
            make.bottom.lessThanOrEqualToSuperview().inset(13)
            make.centerX.equalTo(24)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(13)
            make.leading.equalToSuperview().offset(48)
            make.trailing.equalToSuperview().inset(12)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(48)
            make.trailing.equalToSuperview().inset(12)
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
            ? .dynamic(.Neutral_08)
            : .dynamic(.Neutral_09)
    }

    private func updateColors() {
        layer.borderColor = chooseColor(.Neutral_07).cgColor
    }
}

// MARK: - views

extension SelectPinTypeButton {
    private func setupImageView() {
        imageView.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func setupTitleLabel() {
        titleLabel.font = ._preferredFont(forTextStyle: .body, symbolicTraits: .traitBold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .dynamic(.Neutral_04)
    }

    private func setupSubtitleLabel() {
        subtitleLabel.font = .preferredFont(forTextStyle: .footnote)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .dynamic(.Neutral_05)
        subtitleLabel.numberOfLines = 0
        subtitleLabel.lineBreakMode = .byWordWrapping
    }
}
