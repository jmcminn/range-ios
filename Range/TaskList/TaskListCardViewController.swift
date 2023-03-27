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

    private let headerView = UIView()
    private var onlyMineToggle: SegmentedControl!
    private let headerStroke = UIView()

    private let tableView = UITableView(frame: .zero, style: .plain)

    /// whether to show all tasks (`false`) or only tasks of the current user (`true`)
    private var showOnlyMine = false {
        didSet {
            UserDefaults.showOnlyMineTasks = showOnlyMine
            reloadCollaborations()
        }
    }

    private var collaborationsByStatus: [Status?: [Collaboration]] = [:]
    private var statuses: [Status] = []
    private var expandedStatuses = Set<Status>()
    /// was the first status expaned loaded and marked as expanded already?
    private var firstStatusInitiallyExpanded: Bool = false

    private var headerFont: UIFont { ._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold) }

    /// Token for observing changes in collaborations
    private var notificationToken: NotificationToken?

    /// Initializer
    ///
    /// - Parameters:
    ///     - projectModel:               model to read collaborations from
    init(projectModel: ProjectModel) {
        self.projectModel = projectModel

        super.init(icon: UIImage(systemName: "list.bullet"), title: String(localized: "Task List"))

        showOnlyMine = UserDefaults.showOnlyMineTasks
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
            make.height.equalTo(48)
        }

        setupTableView()
        containerView.insertSubview(tableView, belowSubview: headerView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        reloadCollaborations()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // update the border color for cells
        tableView.reloadData()
    }

    private func reloadCollaborations() {
        var collaborations: Results<Collaboration> =
            projectModel.mainRealm.objects(Collaboration.self)
                .where { (c: Query<Collaboration>) -> Query<Bool> in
                    c.placeholder == false
                        && c.status != nil // only tasks
                        && c.feature.geometry.placeholder == false // has a geometry (just a sanity check)
                        && c.feature.geometry.archivedTimestamp == nil // not archived
                }

        if showOnlyMine {
            collaborations = collaborations
                .where { (c: Query<Collaboration>) -> Query<Bool> in
                    c.assignee == projectModel.currentUser
                }
        }
        notificationToken = collaborations.observe { [weak self] (changes: RealmCollectionChange) in
            guard let self = self else { return }
            switch changes {
            case let .initial(collabs):
                self.updateData(collabs)
            case let .update(collabs, _, _, _):
                self.updateData(collabs)
            case let .error(error):
                Logger.model.error("observing collaborations failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Calculate the sections/rows again and reload table view - no animations for now as it's grouped by the status and
    /// the sections can be hidden so let's not bother with maintaining that state and fine-grained updates for now
    private func updateData(_ collaborations: Results<Collaboration>) {
        collaborationsByStatus = Dictionary(grouping: collaborations) { $0.status }
            .mapValues { values in
                // sort collaborations
                values.sorted { c1, c2 in
                    // no due date last. sort by due date asc
                    // when equal duedate then sort by by creation time desc
                    if c1.dueDateTimestamp == c2.dueDateTimestamp {
                        return c1.timestamp >= c2.timestamp
                    }
                    if c2.dueDateTimestamp == nil { return true }
                    if c1.dueDateTimestamp == nil { return false }
                    return c1.dueDateTimestamp! <= c2.dueDateTimestamp!
                }
            }
        statuses = [Status](projectModel.mainRealm.objects(Status.self)
            .filter { self.collaborationsByStatus[$0] != nil }
            .sorted(by: Status.uiSortingOrder))
        if !firstStatusInitiallyExpanded, let firstStatus = statuses.first {
            // initiate so the first status is expanded
            firstStatusInitiallyExpanded = true
            expandedStatuses.insert(firstStatus)
        }
        tableView.reloadData()
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

        onlyMineToggle = SegmentedControl(items: [
            ActionItem(
                title: String(localized: "All"),
                handler: { [weak self] in
                    self?.showOnlyMine = false
                }
            ),
            ActionItem(
                title: String(localized: "Only Mine"),
                handler: { [weak self] in
                    self?.showOnlyMine = true
                }
            ),
        ])
        if UserDefaults.showOnlyMineTasks {
            onlyMineToggle.setSelectedSegmentIndex(1, animated: false)
        }
        headerView.addSubview(onlyMineToggle)
        onlyMineToggle.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(SegmentedControl.height)
        }

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
    func numberOfSections(in _: UITableView) -> Int {
        statuses.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < statuses.count else { return 0 }
        let status = statuses[section]
        if !expandedStatuses.contains(status) { return 0 }
        return collaborationsByStatus[status]?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CollaborationCell",
                                                 for: indexPath) as! TaskListCollaborationTableViewCell
        if indexPath.section < statuses.count {
            let status = statuses[indexPath.section]
            if indexPath.row < collaborationsByStatus[status]?.count ?? 0,
               let collaboration = collaborationsByStatus[status]?[indexPath.row]
            {
                cell.setCollaboration(collaboration, projectTimeZone: projectModel.projectSummary.timeZone)
            }
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

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        headerFont.lineHeight + 2 * 5 + 2 * 10 // font height + statusView content insets + status view layout insets
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < statuses.count else { return nil }
        let status = statuses[section]

        let view = UIView()
        view.backgroundColor = .dynamic(.Neutral_08)
        let chevron =
            UIImageView(image: UIImage(systemName: "chevron.right",
                                       withConfiguration: UIImage.SymbolConfiguration(pointSize: 18)))
        chevron.contentMode = .center
        chevron.tintColor = .dynamic(.Neutral_05)
        chevron.tag = 999
        if expandedStatuses.contains(status) {
            chevron.transform = CGAffineTransform.identity.rotated(by: CGFloat.pi / 2)
        }
        view.addSubview(chevron)
        chevron.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
        }

        let statusView = StatusView()
        statusView.font = headerFont
        statusView.contentInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        statusView.setStatus(status, count: collaborationsByStatus[status]?.count)
        view.addSubview(statusView)
        statusView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(10)
            make.leading.equalTo(chevron.snp.trailing).offset(8)
        }

        let stroke = UIView()
        stroke.backgroundColor = .dynamic(.Neutral_07)
        view.addSubview(stroke)
        stroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }

        view.tag = section
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(headerTap)))

        return view
    }

    /// Expand/collapse table section on header tap
    @objc private func headerTap(_ recognizer: UITapGestureRecognizer) {
        guard let headerView = recognizer.view else { return }
        let section = headerView.tag
        guard section < statuses.count else { return }
        let status = statuses[section]

        let expanded = expandedStatuses.contains(status)
        let expand = !expanded
        if expand {
            expandedStatuses.insert(status)
        } else {
            expandedStatuses.remove(status)
        }
        let chevronView = headerView.subviews.first { $0.tag == 999 }
        UIView.animate(withDuration: 0.2) {
            if expand {
                chevronView?.transform = CGAffineTransform.identity.rotated(by: CGFloat.pi / 2)
            } else {
                chevronView?.transform = CGAffineTransform.identity
            }
        }
        tableView.reloadSections(IndexSet(integer: section), with: .automatic)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.section < statuses.count,
              let collaborations = collaborationsByStatus[statuses[indexPath.section]],
              indexPath.row < collaborations.count else { return }
        let collaboration = collaborations[indexPath.row]
        UIApplication.shared.sendAction(
            #selector(ProjectFlowActions.showCollaborationAction),
            to: nil,
            from: self,
            for: FlowEvent(collaboration)
        )
    }
}
