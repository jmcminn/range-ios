import Foundation
import UIKit

class CollaborationButton: UIControl {
    private let badge: CollaborationBadgeButton
    private let collaborationIdLabel = UILabel()
    private let collaborationNameLabel = UILabel()
    private let canvasNameLabel = UILabel()
    private let disclosureIndicator = UIImageView()

    init(model: ProjectModel, collaboration: Collaboration) {
        badge = CollaborationBadgeButton(collaboration)
        super.init(frame: .zero)

        if let collaborationID = model.collaborationIdentifier(collaboration) {
            collaborationIdLabel.text = "ID: \(collaborationID)"
        }

        setupViews()

        collaborationNameLabel.text = collaboration.name.isEmpty
            ? (collaboration.status == nil
                ? String(localized: "Untitled photos...")
                : String(localized: "Untitled task..."))
            : collaboration.name
        canvasNameLabel.text = collaboration.feature.first?.geometry.first?.canvas.first?.name
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
        setupCollaborationIdLabel()
        setupCollaborationNameLabel()
        setupCanvasNameLabel()
        setupDisclosureIndicator()

        let stackView = UIStackView(arrangedSubviews: [collaborationNameLabel, canvasNameLabel])
        stackView.axis = .vertical
        stackView.spacing = 2
        if collaborationIdLabel.text != nil {
            stackView.insertArrangedSubview(collaborationIdLabel, at: 0)
        }

        [badge, stackView, disclosureIndicator].forEach(addSubview)
        badge.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
        }
        stackView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(14)
            make.leading.equalTo(badge.snp.trailing).offset(12)
            make.trailing.equalTo(disclosureIndicator.snp.leading).offset(-8)
            make.bottom.equalToSuperview().inset(14)
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

    private func setupCollaborationIdLabel() {
        collaborationIdLabel.font = ._preferredFont(forTextStyle: .caption1, symbolicTraits: .traitBold)
        collaborationIdLabel.adjustsFontForContentSizeCategory = true
        collaborationIdLabel.textColor = .dynamic(.Neutral_05)
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
