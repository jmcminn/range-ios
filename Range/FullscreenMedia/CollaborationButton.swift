import Foundation
import UIKit

class CollaborationButton: UIControl {
    private let badge: CollaborationBadgeView
    private let collaborationNameLabel = UILabel()
    private let canvasNameLabel = UILabel()
    private let disclosureIndicator = UIImageView()

    init(collaboration: Collaboration) {
        badge = CollaborationBadgeView(collaboration)
        super.init(frame: .zero)

        setupViews()

        collaborationNameLabel.text = collaboration.name.isEmpty
            ? (collaboration.status == nil
                ? String(localized: "Untitled photos...")
                : String(localized: "Untitled task..."))
            : collaboration.name
        canvasNameLabel.text = collaboration.feature.first?.geometry.first?.canvas.first?.displayName
        updateColors()
        updateHighlightedColor()
        updateDisclosureImage()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        layer.cornerRadius = 13
        layer.borderWidth = 1

        setupBadge()
        setupCollaborationNameLabel()
        setupCanvasNameLabel()
        setupDisclosureIndicator()

        [badge, collaborationNameLabel, canvasNameLabel, disclosureIndicator].forEach(addSubview)
        badge.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
        }
        collaborationNameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16)
            make.leading.equalTo(badge.snp.trailing).offset(12)
            make.trailing.equalTo(disclosureIndicator.snp.leading).offset(-8)
            make.bottom.equalTo(badge.snp.centerY)
        }
        canvasNameLabel.snp.makeConstraints { make in
            make.top.equalTo(collaborationNameLabel.snp.bottom)
            make.leading.equalTo(collaborationNameLabel)
            make.trailing.equalTo(collaborationNameLabel)
            make.bottom.equalToSuperview().inset(16)
        }
        disclosureIndicator.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
            updateDisclosureImage()
        }
    }

    override open var isHighlighted: Bool {
        didSet {
            updateHighlightedColor()
        }
    }

    private func updateHighlightedColor() {
        backgroundColor = isHighlighted
            ? .dynamic(.Neutral_07)
            : .dynamic(.Neutral_09)
    }

    private func updateColors() {
        layer.borderColor = chooseColor(.Neutral_07).cgColor
    }

    /// when color appearance changes the image needs to be updated too as it has the stroke color
    private func updateDisclosureImage() {
        let image = UIImage(
            systemName: "arrow.forward",
            withConfiguration: UIImage.SymbolConfiguration(font: .systemFont(ofSize: 12, weight: .semibold))
        )?
            .withTintColor(chooseColor(.Neutral_04), renderingMode: .alwaysTemplate)
            .addCircleBackground(
                bgSize: CGSize(width: 32, height: 32),
                bgColor: chooseColor(.Neutral_10),
                strokeColor: chooseColor(.Neutral_07)
            )
        disclosureIndicator.image = image
    }
}

// MARK: - views

extension CollaborationButton {
    private func setupBadge() {
        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.setContentCompressionResistancePriority(.required, for: .horizontal)
        badge.isUserInteractionEnabled = false
    }

    private func setupCollaborationNameLabel() {
        collaborationNameLabel.font = ._preferredFont(forTextStyle: .body, symbolicTraits: .traitBold)
        collaborationNameLabel.adjustsFontForContentSizeCategory = true
        collaborationNameLabel.textColor = .dynamic(.Neutral_04)
    }

    private func setupCanvasNameLabel() {
        canvasNameLabel.font = .preferredFont(forTextStyle: .footnote)
        canvasNameLabel.adjustsFontForContentSizeCategory = true
        canvasNameLabel.textColor = .Primary_Blue_04
    }

    private func setupDisclosureIndicator() {
        disclosureIndicator.setContentHuggingPriority(.required, for: .horizontal)
        disclosureIndicator.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
