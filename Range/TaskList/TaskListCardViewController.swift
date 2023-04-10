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

    private var collaborations: [Collaboration] = []

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

    /// Sort collaborations and update table view
    private func updateData(_ collaborations: Results<Collaboration>) {
        self.collaborations = collaborations.sorted { c1, c2 in
            // sort by last updated desc
            c1.lastUpdatedTimestamp > c2.lastUpdatedTimestamp
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
                title: String(localized: "Only Mine"),
                handler: { [weak self] in
                    self?.showOnlyMine = true
                }
            ),
            ActionItem(
                title: String(localized: "All Tasks"),
                handler: { [weak self] in
                    self?.showOnlyMine = false
                }
            ),
        ])
        if !UserDefaults.showOnlyMineTasks {
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
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        collaborations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CollaborationCell",
                                                 for: indexPath) as! TaskListCollaborationTableViewCell
        if indexPath.row < collaborations.count {
            let collaboration = collaborations[indexPath.row]
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

        guard indexPath.row < collaborations.count else { return }
        let collaboration = collaborations[indexPath.row]
        UIApplication.shared.sendAction(
            #selector(ProjectFlowActions.showCollaborationAction),
            to: nil,
            from: self,
            for: FlowEvent(collaboration)
        )
    }
}
