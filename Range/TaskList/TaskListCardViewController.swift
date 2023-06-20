import Foundation
import OSLog
import Realm
import RealmSwift
import UIKit

/// Card view controller presenting a list of tasks.
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class TaskListCardViewController: SheetCardViewController {
    private let projectModel: ProjectModel
    unowned let canvasContainer: CanvasContainerViewController

    private let headerView = UIView()
    private let headerStroke = UIView()

    private let tableView = UITableView(frame: .zero, style: .plain)

    private let collaborations: Results<Collaboration>
    private var filteredCollaborations: [Collaboration] = []

    private var emptyView: UIView?
    private var emptyFilteredView: UIView?

    /// Token for observing changes in collaborations
    private var notificationToken: NotificationToken?

    private let filters = TaskListFilters()
    private let filtersButton = RoundShadowButton(image: UIImage(named: "filter.search") ?? UIImage())
    private let filtersIndicatorBadge = BadgeView()

    /// Initializer
    ///
    /// - Parameters:
    ///     - projectModel:               model to read collaborations from
    init(projectModel: ProjectModel, canvasContainer: CanvasContainerViewController) {
        self.projectModel = projectModel
        self.canvasContainer = canvasContainer
        collaborations = projectModel.mainRealm.objects(Collaboration.self)
            .where { (c: Query<Collaboration>) -> Query<Bool> in
                c.placeholder == false && c.status != nil // only tasks
            }

        super.init(icon: UIImage(systemName: "list.bullet"), title: String(localized: "Task List"))
    }

    deinit {
        notificationToken?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHeaderView()
        containerView.addSubview(headerView)
        headerView.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            // TODO: 1294
            make.height.equalTo(1)
        }

        setupTableView()
        containerView.insertSubview(tableView, belowSubview: headerView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        setupFiltersButton()
        setupFiltersIndicatorBadge()

        observeCollaborations()

        updateData()
        NotificationCenter.default.addObserver(
            self, selector: #selector(filtersUpdated),
            name: TaskListFilters.UpdateNotificationName, object: nil
        )
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // update the border color for cells
        tableView.reloadData()
    }

    private func observeCollaborations() {
        notificationToken = collaborations.observe { [weak self] (changes: RealmCollectionChange) in
            guard let self = self else { return }
            switch changes {
            case .initial:
                self.updateData()
            case .update:
                self.updateData()
            case let .error(error):
                Logger.model.error("observing collaborations failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Sort collaborations and update table view
    private func updateData() {
        filteredCollaborations = collaborations.filter(filters.match).sorted { c1, c2 in
            // sort by last updated desc
            c1.lastUpdatedTimestamp > c2.lastUpdatedTimestamp
        }
        tableView.reloadData()

        onCollaborationsChanged()
    }

    /// Adjust the UI for changed collaborations
    private func onCollaborationsChanged() {
        updateFiltersIndicatorBadge()

        let emptyTasks = collaborations.isEmpty
        let emptyFilteredTasks = filteredCollaborations.isEmpty

        filtersButton.isHidden = emptyTasks

        if emptyTasks {
            if emptyView == nil {
                emptyView = setupEmptyStateView(fromFilters: false)
                containerView.addSubview(emptyView!)
                emptyView!.snp.makeConstraints { make in
                    make.centerY.equalToSuperview()
                    make.leading.trailing.equalToSuperview()
                }
            }
        } else if emptyFilteredTasks {
            if emptyFilteredView == nil {
                emptyFilteredView = setupEmptyStateView(fromFilters: true)
                containerView.addSubview(emptyFilteredView!)
                emptyFilteredView!.snp.makeConstraints { make in
                    make.centerY.equalToSuperview()
                    make.leading.trailing.equalToSuperview()
                }
            }
        }
        emptyView?.isHidden = !emptyTasks
        emptyFilteredView?.isHidden = emptyTasks || !emptyFilteredTasks
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .max {
            // just make it max, so it doesn't depend on the content height
            return Double.greatestFiniteMagnitude
        } else {
            return super.height(forContainer: cardContainerView, cardPosition: cardPosition)
        }
    }

    override func drivingScrollView() -> UIScrollView? {
        tableView
    }

    private func setupHeaderView() {
        headerView.backgroundColor = view.backgroundColor
        headerStroke.backgroundColor = .dynamic(.Neutral_07)
        headerView.addSubview(headerStroke)
        headerStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
    }

    private func setupTableView() {
        tableView.backgroundColor = view.backgroundColor
        tableView.sectionHeaderTopPadding = 0
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(TaskListCollaborationTableViewCell.self, forCellReuseIdentifier: "CollaborationCell")
        tableView.keyboardDismissMode = .onDrag
    }
}

// MARK: table view delegate

extension TaskListCardViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        filteredCollaborations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CollaborationCell",
                                                 for: indexPath) as! TaskListCollaborationTableViewCell
        if indexPath.row < filteredCollaborations.count {
            let collaboration = filteredCollaborations[indexPath.row]
            cell.setCollaboration(collaboration, projectTimeZone: projectModel.projectSummary.timeZone)
        }
        cell.onCollaborationTapped = { [weak self] collaborationId in
            guard let self = self else { return }
            guard let collaboration = self.projectModel.mainRealm.object(
                ofType: Collaboration.self,
                forPrimaryKey: collaborationId
            ) else { return }
            UIApplication.shared.sendAction(
                #selector(ProjectFlowActions.showCollaborationAction),
                to: nil,
                from: self,
                for: FlowEvent(collaboration)
            )
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.row < filteredCollaborations.count else { return }
        let collaboration = filteredCollaborations[indexPath.row]
        UIApplication.shared.sendAction(
            #selector(ProjectFlowActions.showCollaborationAction),
            to: nil,
            from: self,
            for: FlowEvent(collaboration)
        )
    }
}

// MARK: - media filters

extension TaskListCardViewController {
    private func setupFiltersButton() {
        filtersButton.addTarget(self, action: #selector(showFiltersCard), for: .touchUpInside)
        containerView.addSubview(filtersButton)
        filtersButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.bottom.equalTo(containerView.safeAreaLayoutGuide.snp.bottom).offset(-12)
        }
    }

    private func setupFiltersIndicatorBadge() {
        filtersIndicatorBadge.backgroundColor = .systemGreen
        filtersIndicatorBadge.contentInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        filtersIndicatorBadge.textColor = .Neutral_10
        filtersIndicatorBadge.font = .systemFont(ofSize: 11, weight: .bold)
        filtersIndicatorBadge.isUserInteractionEnabled = false
        filtersButton.addSubview(filtersIndicatorBadge)
        filtersIndicatorBadge.snp.makeConstraints { make in
            make.centerX.equalToSuperview().offset(16)
            make.centerY.equalToSuperview().offset(-16)
        }
    }

    @objc func showFiltersCard() {
        let filtersCardVC = TaskListFiltersCardViewController(model: projectModel, taskListFilters: filters)
        filtersCardVC.installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    @objc func filtersUpdated() {
        // reload collaborations when filters change
        updateData()
    }

    private func updateFiltersIndicatorBadge() {
        let filteredCount = filteredCollaborations.count

        // filters hide the archived tasks by default and we don't want to show the indicator if the
        // only affected tasks are the archived ones
        let allNonArchivedTasks = collaborations.filter { !$0.isArchived }

        if filters.showArchived {
            // don't show the indicator if filter is not impacting the visible tasks
            filtersIndicatorBadge.isHidden = filteredCount == collaborations.count
        } else {
            // don't show the indicator if filter is not impacting the visible non archived tasks
            filtersIndicatorBadge.isHidden = filteredCount == allNonArchivedTasks.count
        }

        filtersIndicatorBadge.text = filteredCount >= 99 ? "99+" : String(filteredCount)
    }
}

extension TaskListCardViewController {
    /// returns the empty state view. There are 2 variants, if fromFilters=false it means that there's not tasks at all,
    /// if fromFilters=true it means that after filtering there's no tasks
    private func setupEmptyStateView(fromFilters: Bool) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let pin = UIImageView(image: UIImage(named: "large_task_pin"))
        view.addSubview(pin)
        pin.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
        }
        let titleLabel = UILabel()
        titleLabel.font = ._preferredFont(forTextStyle: .title3, symbolicTraits: .traitBold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .dynamic(.Neutral_04)
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.text = fromFilters
            ? String(localized: "There are no results...🤔")
            : String(localized: "It looks like there aren’t any tasks...🤔")
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(pin.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(36)
        }
        let descriptionLabel = UILabel()
        descriptionLabel.font = .preferredFont(forTextStyle: .body)
        descriptionLabel.adjustsFontForContentSizeCategory = true
        descriptionLabel.textColor = .dynamic(.Neutral_05)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center

        if fromFilters {
            // use attributed string to insert the filter icon
            let attributedText = NSMutableAttributedString(string: "Try adjusting your ")
            let filterImage = UIImage(systemName: "line.3.horizontal.decrease.circle") ?? UIImage()
            let filterAttachment = NSTextAttachment(image: filterImage)
            attributedText.append(NSAttributedString(attachment: filterAttachment))
            attributedText.append(NSAttributedString(string: " filters"))
            descriptionLabel.attributedText = attributedText
        } else {
            descriptionLabel.text = String(localized: "Start adding task pins to the canvas")
        }

        view.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(36)
            make.bottom.equalToSuperview()
        }
        return view
    }
}
