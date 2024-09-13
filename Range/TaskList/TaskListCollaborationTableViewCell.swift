import Foundation
import UIKit

/// Table cell for displaying collaboration data
class TaskListCollaborationTableViewCell: UITableViewCell {
    /// The cell has 2 variants based on the reuseIdentifier
    enum Variant: String {
        case normal = "TaskCell"
        case selectable = "SelectableTaskCell"

        static func identifier(forSelectable: Bool) -> String {
            forSelectable ? selectable.rawValue : normal.rawValue
        }
    }

    private var selectedView: UIImageView?
    private let idLabel = UILabel()
    private let nameLabel = UILabel()
    private var additionalInformationButton: RangeButton!

    private let detailsScrollView = UIScrollView()
    private let detailsStackView = UIStackView()
    private let lastUpdatedLabel = UILabel()
    private let bottomStroke = UIView()
    /// details scroll view has user interaction enabled, so tapping on it will prevent didSelectRow callback, we need to add a separate handler
    var onCollaborationTapped: ((String) -> Void)?

    private var model: ProjectModel?
    /// stored to be used for callback
    private var collaborationId: String?

    private let selectable: Bool

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        selectable = reuseIdentifier == Variant.identifier(forSelectable: true)
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .dynamic(.Neutral_10)

        if selectable {
            setupSelectionViews()
        }

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .dynamic(.Neutral_08)

        setupViews()

        [idLabel, nameLabel, additionalInformationButton, detailsScrollView, lastUpdatedLabel, bottomStroke]
            .forEach(contentView.addSubview)

        idLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(15)
            make.leading.equalToSuperview().inset(selectable ? 64 : 16)
            make.trailing.equalToSuperview().inset(14)
        }
        nameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(15)
            make.leading.equalToSuperview().inset(selectable ? 64 : 16)
            make.trailing.equalToSuperview().inset(14)
        }
        additionalInformationButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.width.height.equalTo(32)
            make.centerY.equalTo(nameLabel)
        }

        detailsScrollView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(nameLabel.snp.bottom)
            make.leading.equalToSuperview().inset(selectable ? 48 : 0)
            make.trailing.equalToSuperview()
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

    private func setupSelectionViews() {
        let selectBackground = UIView()
        selectBackground.backgroundColor = .dynamic(.Neutral_09)
        contentView.addSubview(selectBackground)
        selectBackground.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(48)
        }

        selectedView = UIImageView()
        selectedView!.tintColor = .dynamic(.Neutral_04)
        selectBackground.addSubview(selectedView!)
        selectedView!.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        mark(selected: false)
    }

    private func setupViews() {
        idLabel.font = ._preferredFont(forTextStyle: .caption1, symbolicTraits: .traitBold)
        idLabel.textColor = .dynamic(.Neutral_05)
        idLabel.adjustsFontForContentSizeCategory = true

        nameLabel.font = .preferredFont(forTextStyle: .headline)
        nameLabel.textColor = .dynamic(.Neutral_04)
        nameLabel.adjustsFontForContentSizeCategory = true

        additionalInformationButton = RangeButton(
            configuration: UIButton.Configuration.iconButton(
                backgroundColor: .dynamic(.Neutral_10), foregroundColor: .dynamic(.Neutral_04),
                strokeColor: .dynamic(.Neutral_07), imagePointSize: 12
            ),
            primaryAction: UIAction(image: UIImage(systemName: "globe")) { [weak self] _ in
                self?.additionalInformationAction()
            }
        )
        .withCustomRangeHighlightColor()
        .withTapAreaInsets(UIEdgeInsets(top: -4, left: -4, bottom: -4, right: -4))

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

    func setCollaboration(_ collaboration: Collaboration, model: ProjectModel) {
        self.model = model
        collaborationId = collaboration.id

        additionalInformationButton.isHidden = selectable || !collaboration.isPlacedOnMap

        if let collaborationID = model.collaborationIdentifier(collaboration) {
            idLabel.isHidden = false
            idLabel.text = "ID \(collaborationID)"
            nameLabel.snp.remakeConstraints { make in
                make.top.greaterThanOrEqualTo(idLabel.snp.bottom).offset(2)
                make.leading.equalToSuperview().inset(selectable ? 64 : 16)
                if additionalInformationButton.isHidden {
                    make.trailing.equalToSuperview().inset(14)
                } else {
                    make.trailing.equalTo(additionalInformationButton.snp.leading).offset(-4)
                }
            }
            additionalInformationButton.snp.remakeConstraints { make in
                make.width.height.equalTo(32)
                make.trailing.equalToSuperview().inset(16)
                make.centerY.equalTo(idLabel.snp.bottom)
            }
        } else {
            idLabel.isHidden = true
            nameLabel.snp.remakeConstraints { make in
                make.top.equalToSuperview().inset(15)
                make.leading.equalToSuperview().inset(selectable ? 64 : 16)
                if additionalInformationButton.isHidden {
                    make.trailing.equalToSuperview().inset(14)
                } else {
                    make.trailing.equalTo(additionalInformationButton.snp.leading).offset(-4)
                }
            }
            additionalInformationButton.snp.remakeConstraints { make in
                make.width.height.equalTo(32)
                make.trailing.equalToSuperview().inset(16)
                make.centerY.equalTo(nameLabel)
            }
        }

        nameLabel.text = collaboration.name.isEmpty
            ? (collaboration.status == nil
                ? String(localized: "Untitled photos...")
                : String(localized: "Untitled task..."))
            : collaboration.name
        // it animates the views in a weird way
        UIView.performWithoutAnimation {
            if collaboration.isArchived {
                // show status only if not archived
                let statusView = StatusView()
                statusView.contentInsets = .init(top: 4, left: 8, bottom: 4, right: 8)
                statusView.setArchived()
                detailsStackView.addArrangedSubview(statusView)
            } else if let status = collaboration.status {
                // show status only if not archived
                let statusView = StatusView()
                statusView.contentInsets = .init(top: 4, left: 8, bottom: 4, right: 8)
                statusView.setStatus(status)
                detailsStackView.addArrangedSubview(statusView)
            }
            if let dueDateTimestamp = collaboration.dueDateTimestamp {
                detailsStackView.addArrangedSubview(PillView(
                    iconName: "calendar",
                    text: Date.dueDateFormat2(dueDateTimestamp, timeZone: model.projectSummary.timeZone),
                    style: collaboration.isOverdue ? .red : .default
                ))
            }
            if let assignee = collaboration.assignee {
                detailsStackView.addArrangedSubview(PillView(
                    iconName: "person", text: assignee.displayName,
                    textAttributes: [.strikethroughStyle: assignee.strikethroughStyle]
                ))
            }
            if let canvasName = collaboration.geometry.first?.canvas.first?.name {
                detailsStackView.addArrangedSubview(PillView(iconName: "square.3.layers.3d", text: canvasName))
            }
            detailsStackView.addArrangedSubview(PillView(iconName: "tag", text: String(collaboration.tags.count)))

            lastUpdatedLabel.text = String(localized: "Last updated") + " " + Date
                .format1Ago(collaboration.lastUpdatedTimestamp)
            layoutIfNeeded()
        }
    }

    func additionalInformationAction() {
        guard let collaborationId, let model, let collaboration = model.mainRealm.object(
            ofType: Collaboration.self,
            forPrimaryKey: collaborationId
        ) else { return }
        
        // HACK: close the search task keyboard
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        UIApplication.shared.sendAction(
            #selector(ProjectFlowController.showAdditionalInformation), to: nil, from: self,
            for: FlowEvent(collaboration)
        )
    }

    func mark(selected: Bool) {
        selectedView?.image = selected
            ? UIImage(named: "checkmark_checked")
            : UIImage().addCircleBackground(bgSize: CGSize(width: 20, height: 20),
                                            bgColor: .dynamic(.Neutral_10),
                                            strokeColor: .dynamic(.Neutral_07))
    }

    override func prepareForReuse() {
        model = nil
        nameLabel.text = nil
        detailsStackView.arrangedSubviews.forEach {
            detailsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        mark(selected: false)
    }

    @objc private func scrollViewTapped() {
        guard let collaborationId = collaborationId else { return }
        onCollaborationTapped?(collaborationId)
    }
}
