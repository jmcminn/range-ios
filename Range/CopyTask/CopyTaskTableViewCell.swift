import Foundation
import UIKit

// TODO:
// DocumentMediaCollectionViewCell.fileSizeLabel for bubbles NO, no image...
// TaskListCollaborationTableViewCell.CollaborationPillView... -> image + text
// + reuse tags but with variable height and smaller vertical insets

/// Table cell for displaying collaboration data
class CopyTaskTableViewCell: UITableViewCell {
    private let badgeView = UIView()
    private let nameLabel = UILabel()
    private let descriptionLabel = LabelWithTextInsets()
    private let detailsScrollView = UIScrollView()
    private let detailsStackView = UIStackView()
    private let tagsScrollView = UIScrollView()
    private let tagsStackView = UIStackView()
    private let bottomStroke = UIView()
    /// details scroll view has user interaction enabled, so tapping on it will prevent didSelectRow callback, we need to add a separate handler
    var onCollaborationTapped: ((String) -> Void)?
    /// stored to be used for callback
    private var collaborationId: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .dynamic(.Neutral_10)

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .dynamic(.Neutral_08)

        setupViews()

        [badgeView, nameLabel, descriptionLabel, detailsScrollView, tagsScrollView, bottomStroke]
            .forEach(contentView.addSubview)

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

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom)
            make.leading.equalTo(badgeView.snp.trailing).offset(8)
            make.trailing.equalToSuperview().inset(14)
        }

        detailsScrollView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(descriptionLabel.snp.bottom).offset(4)
            make.top.greaterThanOrEqualTo(badgeView.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview()
        }

        tagsScrollView.snp.makeConstraints { make in
            make.top.equalTo(detailsScrollView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(12) // should be 16 but 4 is included in the pill view
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
        nameLabel.textColor = .dynamic(.Neutral_04)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail

        descriptionLabel.font = .preferredFont(forTextStyle: .subheadline)
        descriptionLabel.textColor = .dynamic(.Neutral_05)
        descriptionLabel.adjustsFontForContentSizeCategory = true
        descriptionLabel.numberOfLines = 2
        descriptionLabel.lineBreakMode = .byTruncatingTail

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

        tagsScrollView.alwaysBounceHorizontal = true
        tagsScrollView.showsHorizontalScrollIndicator = false
        tagsScrollView.contentInset = UIEdgeInsets(top: 0, left: 44, bottom: 0, right: 8)
        tagsStackView.axis = .horizontal
        tagsStackView.alignment = .center
        tagsStackView.spacing = 8
        tagsScrollView.addSubview(tagsStackView)
        tagsStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(tagsScrollView)
        }
        tagsStackView.isUserInteractionEnabled = false
        tagsScrollView
            .addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(scrollViewTapped)))

        bottomStroke.backgroundColor = .dynamic(.Neutral_07)
    }

    func setCollaboration(_ collaboration: Collaboration, projectModel: ProjectModel) {
        collaborationId = collaboration.id

        let initialStatusColor = projectModel.mainRealm.objects(Status.self).first(where: { $0.isInitial })?
            .color ?? .Primary_Blue_04

        badgeView.backgroundColor = initialStatusColor
        nameLabel.text = collaboration.name.isEmpty
            ? (collaboration.status == nil
                ? String(localized: "Untitled photos...")
                : String(localized: "Untitled task..."))
            : collaboration.name

        if let description = collaboration.collaborationDescription, !description.isEmpty {
            descriptionLabel.text = description
            descriptionLabel.textInsets = UIEdgeInsets(top: 4, left: 0, bottom: 0, right: 0)
        } else {
            // collapse description
            descriptionLabel.textInsets = .zero
        }

        let detailsBgColor = UIColor.dynamic(.Neutral_09)
        if let assignee = collaboration.assignee, assignee.participation == .active {
            detailsStackView.addArrangedSubview(PillView(
                iconName: "person", text: assignee.displayName,
                verticalPadding: 4, backgroundColor: detailsBgColor
            ))
        } else {
            detailsStackView.addArrangedSubview(PillView(
                iconName: "person", text: String(localized: "No Assignee"),
                verticalPadding: 4, backgroundColor: detailsBgColor,
                style: .disabled
            ))
        }
        if let dueDateTimestamp = collaboration.dueDateTimestamp {
            detailsStackView.addArrangedSubview(PillView(
                iconName: "calendar",
                text: Date.dueDateFormat2(dueDateTimestamp, timeZone: projectModel.projectSummary.timeZone),
                verticalPadding: 4, backgroundColor: detailsBgColor,
                style: collaboration.isOverdue ? .red : .default
            ))
        } else {
            detailsStackView.addArrangedSubview(PillView(
                iconName: "calendar", text: String(localized: "No Due Date"),
                verticalPadding: 4, backgroundColor: detailsBgColor,
                style: .disabled
            ))
        }

        let tagsBgColor = UIColor.Primary_Blue_01
        for tag in collaboration.tags {
            tagsStackView.addArrangedSubview(PillView(
                iconName: "tag", text: tag.name, verticalPadding: 4, backgroundColor: tagsBgColor, style: .tag
            ))
        }
    }

    override func prepareForReuse() {
        nameLabel.text = nil
        descriptionLabel.text = nil
        detailsStackView.arrangedSubviews.forEach {
            detailsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        tagsStackView.arrangedSubviews.forEach {
            tagsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    @objc private func scrollViewTapped() {
        guard let collaborationId = collaborationId else { return }
        onCollaborationTapped?(collaborationId)
    }
}
