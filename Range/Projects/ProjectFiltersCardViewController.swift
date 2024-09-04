import Foundation
import UIKit

class ProjectFiltersCardViewController: SheetCardViewController {
    private let filters: ProjectFilters

    private var resetButton: RangeButton!
    private var projectStateToggle: SegmentedControl!

    init(model: OrganizationModel, filters: ProjectFilters) {
        self.filters = filters
        super.init(
            icon: UIImage(named: "filter.search"),
            title: String(localized: "Projects Showing")
        )

        let projects = model.projects
        let counts: [ProjectFilters.ProjectStateFilter: Int] = [
            .all: projects.count,
            .active: projects.filter { $0.isArchived == false }.count,
            .archived: projects.filter { $0.isArchived == true }.count,
        ]
        let projectStateActionItems = ProjectFilters.ProjectStateFilter.allCases.map { option in
            let title = "\(option.displayName) (\(counts[option] ?? 0))"
            return ActionItem(title: title) { [weak self] in
                self?.filters.projectStateFilter = option
            }
        }
        projectStateToggle = SegmentedControl(items: projectStateActionItems)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupResetButton()

        containerView.addSubview(projectStateToggle)
        projectStateToggle.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.height.equalTo(SegmentedControl.height)
        }

        updateControlsStateFromFilters()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(
            self, selector: #selector(filtersUpdated),
            name: ProjectFilters.UpdateNotificationName, object: nil
        )
        filtersUpdated()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    @objc func filtersUpdated() {
        resetButton.isHidden = filters.hasDefaultValues
    }

    private func setupResetButton() {
        guard resetButton == nil else { return }
        var config = UIButton.Configuration.filled()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        config.baseBackgroundColor = .Green_01
        config.baseForegroundColor = .dynamic(.Neutral_04)
        config.cornerStyle = .fixed
        config.background.cornerRadius = 15
        config.background.strokeColor = .systemGreen
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: .subheadline)
            return outgoing
        }
        resetButton = RangeButton(
            configuration: config,
            primaryAction: UIAction(title: String(localized: "Reset")) { [weak self] _ in
                self?.filters.resetToDefaults()
                self?.updateControlsStateFromFilters()
            }
        )
        .withCustomRangeHighlightColor()

        // more vertical tap area as button is only 30 points high
        resetButton.tapAreaInsets = UIEdgeInsets(top: -10, left: 0, bottom: -10, right: 0)

        sheetHeaderView.addSubview(resetButton)
        resetButton.snp.makeConstraints { make in
            make.centerY.equalTo(closeButton)
            make.trailing.equalTo(closeButton.snp.leading).offset(-8)
            make.height.equalTo(30)
        }
    }

    private func updateControlsStateFromFilters() {
        let projectStateToggleOptionIndex = ProjectFilters.ProjectStateFilter.allCases
            .lastIndex(of: filters.projectStateFilter) ?? 0
        projectStateToggle.setSelectedSegmentIndex(projectStateToggleOptionIndex, animated: true)
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        let baseHeight = super.height(forContainer: cardContainerView, cardPosition: cardPosition)

        if cardPosition == .max {
            view.layoutIfNeeded()
            return baseHeight + SegmentedControl.height + 16
        }
        return baseHeight
    }
}
