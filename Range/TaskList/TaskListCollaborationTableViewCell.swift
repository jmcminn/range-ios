import Foundation
import UIKit

/// Table cell for displaying collaboration data
class TaskListCollaborationTableViewCell: UITableViewCell {
    private let nameLabel = UILabel()
    private let detailsScrollView = UIScrollView()
    private let detailsStackView = UIStackView()
    private let lastUpdatedLabel = UILabel()
    private let bottomStroke = UIView()
    /// details scroll view has user interaction enabled, so tapping on it will prevent didSelectRow callback, we need to add a separate handler
    var onCollaborationTapped: ((String) -> Void)?
    /// stored to be used for callback
    private var collaborationId: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .dynamic(.Neutral_10)

        setupViews()

        [nameLabel, detailsScrollView, lastUpdatedLabel, bottomStroke].forEach(contentView.addSubview)

        nameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(15)
            make.leading.equalToSuperview().inset(16)
            make.trailing.equalToSuperview().inset(14)
        }

        detailsScrollView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(nameLabel.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }

        lastUpdatedLabel.snp.makeConstraints { make in
            make.top.equalTo(detailsScrollView.snp.bottom).offset(2)
            make.leading.equalTo(nameLabel)
            make.trailing.equalToSuperview().inset(14)
            make.bottom.equalToSuperview().inset(14)
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
        nameLabel.font = .preferredFont(forTextStyle: .subheadline)
        nameLabel.textColor = .dynamic(.Neutral_04)
        nameLabel.adjustsFontForContentSizeCategory = true

        detailsScrollView.alwaysBounceHorizontal = true
        detailsScrollView.showsHorizontalScrollIndicator = false
        detailsScrollView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 8)
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

        lastUpdatedLabel.font = .preferredFont(forTextStyle: .caption2)
        lastUpdatedLabel.textColor = .dynamic(.Neutral_05)
        lastUpdatedLabel.adjustsFontForContentSizeCategory = true

        bottomStroke.backgroundColor = .dynamic(.Neutral_07)
    }

    func setCollaboration(_ collaboration: Collaboration, projectTimeZone: TimeZone) {
        collaborationId = collaboration.id
        nameLabel.text = collaboration.name.isEmpty
            ? (collaboration.status == nil
                ? String(localized: "Untitled photos...")
                : String(localized: "Untitled task..."))
            : collaboration.name
        if let status = collaboration.status {
            let statusView = StatusView()
            statusView.contentInsets = .init(top: 4, left: 8, bottom: 4, right: 8)
            statusView.setStatus(status)
            detailsStackView.addArrangedSubview(statusView)
        }
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

        lastUpdatedLabel.text = String(localized: "Last updated") + " " + Date
            .format1Ago(collaboration.lastUpdatedTimestamp)
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
