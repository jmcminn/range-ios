import Foundation
import UIKit

/// Table cell for displaying collaboration data
class TaskListCollaborationTableViewCell: UITableViewCell {
    private let badgeView = UIView()
    private let nameLabel = UILabel()
    private let detailsScrollView = UIScrollView()
    private let detailsStackView = UIStackView()
    private let bottomStroke = UIView()
    /// details scroll view has user interaction enabled, so tapping on it will prevent didSelectRow callback, we need to add a separate handler
    var onCollaborationTapped: ((String) -> Void)?
    /// stored to be used for callback
    private var collaborationId: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .dynamic(.Neutral_10)

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

        nameLabel.font = .preferredFont(forTextStyle: .headline)
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
        detailsStackView.isUserInteractionEnabled = false
        detailsScrollView
            .addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(scrollViewTapped)))

        bottomStroke.backgroundColor = .dynamic(.Neutral_07)
    }

    func setCollaboration(_ collaboration: Collaboration, projectTimeZone: TimeZone) {
        collaborationId = collaboration.id
        badgeView.backgroundColor = collaboration.status?.color
        nameLabel.text = collaboration.name.isEmpty
            ? (collaboration.status == nil
                ? String(localized: "Untitled photos...")
                : String(localized: "Untitled task..."))
            : collaboration.name
        if let dueDateTimestamp = collaboration.dueDateTimestamp {
            detailsStackView.addArrangedSubview(PillView(
                iconName: "calendar",
                text: Date.dueDateFormat2(dueDateTimestamp, timeZone: projectTimeZone),
                style: collaboration.isOverdue ? .red : .default
            ))
        }
        if let assignee = collaboration.assignee {
            detailsStackView.addArrangedSubview(PillView(iconName: "person", text: assignee.displayName))
        }
        if let canvasName = collaboration.feature.first?.geometry.first?.canvas.first?.displayName {
            detailsStackView.addArrangedSubview(PillView(iconName: "square.3.layers.3d", text: canvasName))
        }
        detailsStackView.addArrangedSubview(PillView(iconName: "tag", text: String(collaboration.tags.count)))
        detailsStackView.addArrangedSubview(PillView(
            iconName: "clock", text: Date.format1Ago(collaboration.lastUpdatedTimestamp)
        ))
    }

    override func prepareForReuse() {
        nameLabel.text = nil
        detailsStackView.arrangedSubviews.forEach {
            detailsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    @objc private func scrollViewTapped() {
        guard let collaborationId = collaborationId else { return }
        onCollaborationTapped?(collaborationId)
    }
}
