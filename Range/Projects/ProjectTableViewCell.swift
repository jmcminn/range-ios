import Foundation
import UIKit

/// Table view cell for displaying ProjectSummary
class ProjectTableViewCell: UITableViewCell {
    private let idLabel = UILabel()
    private let nameLabel = UILabel()
    private var moreButton: UIButton!
    private let descriptionLabel = UILabel()
    private let addressLabel = UILabel()
    private let tasksLabel = UILabel()
    private let statusCountScrollView = UIScrollView()
    private let statusCountStackView = UIStackView()

    private var projectId: String?
    private var model: OrganizationModel?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in the view controller

        setupViews()

        [idLabel, nameLabel, moreButton, descriptionLabel, addressLabel, tasksLabel, statusCountScrollView]
            .forEach(contentView.addSubview)

        idLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16)
            make.leading.equalTo(contentView.snp.leadingMargin).offset(16)
            make.trailing.equalTo(contentView.snp.trailingMargin).offset(-16)
        }
        nameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16)
            make.leading.equalTo(contentView.snp.leadingMargin).offset(16)
            make.trailing.equalTo(contentView.snp.trailingMargin).offset(-16)
        }
        moreButton.snp.makeConstraints { make in
            make.width.height.equalTo(40)
            make.top.equalToSuperview().offset(4)
            make.trailing.equalTo(contentView.snp.trailingMargin).offset(-4)
        }
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(8)
            make.leading.trailing.equalTo(nameLabel)
        }
        addressLabel.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(12)
            make.leading.trailing.equalTo(nameLabel)
            make.bottom.equalToSuperview().inset(16)
        }
        tasksLabel.snp.makeConstraints { make in
            make.top.equalTo(addressLabel.snp.bottom).offset(12)
            make.leading.trailing.equalTo(nameLabel)
        }
        statusCountScrollView.snp.makeConstraints { make in
            make.top.equalTo(tasksLabel.snp.bottom).offset(4) // 8 is in the view height, so it's easier to scroll
            make.leading.equalTo(contentView.snp.leadingMargin)
            make.trailing.equalTo(contentView.snp.trailingMargin)
            make.bottom.equalToSuperview().inset(8) // 8 is in the view height, so it's easier to scroll
        }
        // the statusCountScrollView has user interaction disabled so the cell selection works
        // when tapped on status count, but we still want it's pan gesture to work
        contentView.addGestureRecognizer(statusCountScrollView.panGestureRecognizer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        idLabel.textColor = .dynamic(.Neutral_05)
        idLabel.font = .preferredFont(forTextStyle: .footnote)
        idLabel.adjustsFontForContentSizeCategory = true

        nameLabel.numberOfLines = 0
        nameLabel.textColor = .dynamic(.Neutral_04)
        nameLabel.font = ._preferredFont(forTextStyle: .body, symbolicTraits: .traitBold)

        moreButton = FeedItemCells.createMoreButton(handler: { [weak self] _ in
            self?.moreAction()
        })

        descriptionLabel.numberOfLines = 0
        descriptionLabel.textColor = .dynamic(.Neutral_05)
        descriptionLabel.font = .preferredFont(forTextStyle: .footnote)

        addressLabel.numberOfLines = 0
        addressLabel.textColor = .dynamic(.Neutral_05)
        addressLabel.font = .preferredFont(forTextStyle: .footnote)

        tasksLabel.textColor = .dynamic(.Neutral_04)
        tasksLabel.font = ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
        tasksLabel.adjustsFontForContentSizeCategory = true

        statusCountScrollView.isUserInteractionEnabled = false
        statusCountScrollView.alwaysBounceHorizontal = true
        statusCountScrollView.showsHorizontalScrollIndicator = false
        statusCountScrollView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        statusCountStackView.axis = .horizontal
        statusCountStackView.alignment = .center
        statusCountStackView.spacing = 8
        statusCountScrollView.addSubview(statusCountStackView)
        statusCountStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
        }
    }

    func setProject(_ project: ProjectSummary, model: OrganizationModel) {
        guard !project.isInvalidated else { return }
        projectId = project.id
        self.model = model
        moreButton.isHidden = model.currentUser.organizationRole != .Admin
        if let identifier = project.identifier {
            idLabel.text = "ID: \(identifier)"
            idLabel.isHidden = false
            nameLabel.snp.remakeConstraints { make in
                make.top.equalTo(idLabel.snp.bottom).offset(2)
                make.leading.equalTo(contentView.snp.leadingMargin).offset(16)
                make.trailing.equalTo(contentView.snp.trailingMargin).offset(-16)
            }
        } else {
            idLabel.text = nil
            idLabel.isHidden = true
            nameLabel.snp.remakeConstraints { make in
                make.top.equalToSuperview().inset(16)
                make.leading.equalTo(contentView.snp.leadingMargin).offset(16)
                if moreButton.isHidden {
                    make.trailing.equalTo(contentView.snp.trailingMargin).offset(-16)
                } else {
                    make.trailing.equalTo(moreButton.snp.leading).offset(-8)
                }
            }
        }
        nameLabel.text = project.name
        descriptionLabel.text = project.projectDescription

        let addressString = NSMutableAttributedString()
        if let pinImage = UIImage(systemName: "pin") {
            let pinAttachment = NSTextAttachment(image: pinImage)
            addressString.append(NSAttributedString(attachment: pinAttachment))
            addressString.append(NSAttributedString(string: " "))
        }
        if let address = project.address {
            addressString.append(NSAttributedString(string: address))
        }
        addressLabel.attributedText = addressString

        if project.statusTaskCounts.isEmpty {
            tasksLabel.isHidden = true
            statusCountScrollView.isHidden = true
            addressLabel.snp.remakeConstraints { make in
                make.top.equalTo(descriptionLabel.snp.bottom).offset(12)
                make.leading.trailing.equalTo(nameLabel)
                make.bottom.equalToSuperview().inset(16)
            }
        } else {
            for status in project.statusTaskCounts {
                let text = "\(status.name) (\(status.taskCount))"
                let statusView = PillView(
                    iconName: nil, text: text, verticalPadding: 8, backgroundColor: status.color, style: .flat
                )
                if status.taskCount == 0 {
                    statusView.alpha = 0.3
                }
                statusCountStackView.addArrangedSubview(statusView)
            }
            let totalTasksCount = project.statusTaskCounts.sum(of: \.taskCount)
            tasksLabel.text = "Tasks (\(totalTasksCount))"
            tasksLabel.isHidden = false
            statusCountScrollView.isHidden = false
            addressLabel.snp.remakeConstraints { make in
                make.top.equalTo(descriptionLabel.snp.bottom).offset(12)
                make.leading.trailing.equalTo(nameLabel)
            }
        }
    }

    private func moreAction() {
        guard let model, let projectId, let project = model.mainRealm.object(
            ofType: ProjectSummary.self,
            forPrimaryKey: projectId
        ) else { return }
        UIApplication.shared.sendAction(
            #selector(ProjectsFlowController.moreAction), to: nil, from: self,
            for: FlowEvent(project)
        )
    }

    override func prepareForReuse() {
        nameLabel.text = nil
        descriptionLabel.text = nil
        addressLabel.attributedText = nil
        statusCountScrollView.contentOffset = .init(x: -statusCountScrollView.contentInset.left, y: 0)
        statusCountStackView.arrangedSubviews.forEach {
            statusCountStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }
}
