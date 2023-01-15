import Foundation
import UIKit

/// A pill view displaying one of the collaboration details
class CollaborationPillView: UIView {
    private var font: UIFont {
        ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
    }

    private let borderView = UIView()
    private let iconView = UIImageView()
    private let label = UILabel()
    private let isRed: Bool

    init(iconName: String, text: String, isRed: Bool = false) {
        self.isRed = isRed
        super.init(frame: .zero)

        borderView.layer.borderWidth = 1
        borderView.backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)

        iconView.image = UIImage(systemName: iconName, withConfiguration: UIImage.SymbolConfiguration(font: font))
        iconView.tintColor = isRed ? .Red_03 : .dynamicColor(light: .Neutral_07, dark: .Neutral_04)

        label.text = text
        label.font = font
        label.adjustsFontForContentSizeCategory = true
        label.textColor = iconView.tintColor

        updateColors()

        addSubview(borderView)
        borderView.addSubview(iconView)
        borderView.addSubview(label)
        borderView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(8)
            make.leading.trailing.equalToSuperview()
        }
        iconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().inset(8)
        }
        label.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(6)
            make.trailing.equalToSuperview().inset(8)
            make.top.bottom.equalToSuperview().inset(4)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        borderView.layer.cornerRadius = borderView.frame.height / 2
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    private func updateColors() {
        borderView.layer.borderColor = (isRed
            ? UIColor.Red_03
            : UIColor.dynamicColor(light: .Neutral_04, dark: .Neutral_07))
            .cgColor
    }
}

/// Table cell for displaying collaboration data
class ListViewCollaborationTableViewCell: UITableViewCell {
    private let badgeView = UIView()
    private let nameLabel = UILabel()
    private let detailsScrollView = UIScrollView()
    private let detailsStackView = UIStackView()
    private let bottomStroke = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        setupViews()

        [badgeView, nameLabel, detailsScrollView, bottomStroke].forEach(contentView.addSubview)

        badgeView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
            make.leading.equalToSuperview().inset(14)
            make.centerY.equalTo(nameLabel.snp.centerY)
        }

        nameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(15)
            make.leading.equalTo(badgeView.snp.trailing).offset(8)
            make.trailing.equalToSuperview().inset(14)
        }

        detailsScrollView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(nameLabel.snp.bottom)
            make.top.greaterThanOrEqualTo(badgeView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(6)
        }

        bottomStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        badgeView.layer.cornerRadius = 10
        let tickView = UIImageView(image: UIImage(named: "tick.smaller"))
        badgeView.addSubview(tickView)
        tickView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        nameLabel.font = .preferredFont(forTextStyle: .subheadline)
        nameLabel.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        nameLabel.adjustsFontForContentSizeCategory = true

        detailsScrollView.alwaysBounceHorizontal = true
        detailsScrollView.showsHorizontalScrollIndicator = false
        detailsScrollView.contentInset = UIEdgeInsets(top: 0, left: 44, bottom: 0, right: 8)
        detailsStackView.axis = .horizontal
        detailsStackView.alignment = .center
        detailsStackView.spacing = 8
        detailsScrollView.addSubview(detailsStackView)
        detailsStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(detailsScrollView)
        }

        bottomStroke.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)
    }

    func setCollaboration(_ collaboration: Collaboration, projectTimeZone: TimeZone) {
        badgeView.backgroundColor = collaboration.status?.color
        nameLabel.text = collaboration.name.isEmpty
            ? (collaboration.status == nil
                ? String(localized: "Untitled photos...")
                : String(localized: "Untitled task..."))
            : collaboration.name
        if let dueDateTimestamp = collaboration.dueDateTimestamp {
            detailsStackView.addArrangedSubview(CollaborationPillView(
                iconName: "calendar",
                text: Date.dueDateFormat2(dueDateTimestamp, timeZone: projectTimeZone),
                isRed: collaboration.isOverdue
            ))
        }
        if let canvasName = collaboration.feature.first?.geometry.first?.canvas.first?.displayName {
            detailsStackView.addArrangedSubview(CollaborationPillView(iconName: "square.3.layers.3d", text: canvasName))
        }
        detailsStackView.addArrangedSubview(
            CollaborationPillView(iconName: "tag", text: String(collaboration.tags.count))
        )
        detailsStackView.addArrangedSubview(
            CollaborationPillView(iconName: "clock", text: Date.format1Ago(collaboration.lastUpdatedTimestamp))
        )
    }

    override func prepareForReuse() {
        nameLabel.text = nil
        detailsStackView.arrangedSubviews.forEach {
            detailsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }
}
