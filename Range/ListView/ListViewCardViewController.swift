import Foundation
import OSLog
import Realm
import RealmSwift
import UIKit

/// Card view controller presenting a list of collaborations.
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class ListViewCardViewController: SheetCardViewController {
    private let projectModel: ProjectModel

    private let headerStroke = UIView()

    private let tableView = UITableView(frame: .zero, style: .plain)

    /// whether to show all tasks (`false`) or only tasks of the current user (`true`)
    private var showOnlyMine = false

    private var collaborationsByStatus: [Status?: [Collaboration]] = [:]
    private var statuses: [Status] = []
    private var expandedSections: Set<Int> = .init(arrayLiteral: 0)

    private var headerFont: UIFont { .preferredFont(forTextStyle: .subheadline) }

    /// Token for observing changes in collaborations
    private var notificationToken: NotificationToken?

    /// Initializer
    ///
    /// - Parameters:
    ///     - projectModel:               model to read collaborations from
    init(projectModel: ProjectModel) {
        self.projectModel = projectModel

        super.init(icon: UIImage(systemName: "list.bullet"), title: String(localized: "List View"))
    }

    deinit {
        notificationToken?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHeaderStroke()
        sheetHeaderView.addSubview(headerStroke)
        headerStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }

        setupTableView()
        containerView.insertSubview(tableView, belowSubview: sheetHeaderView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        reloadCollaborations()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // update the border color for cells
        tableView.reloadData()
        updateHeaderShadow()
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
            .filter { self.collaborationsByStatus[$0] != nil })
            .sorted(by: { s1, s2 in
                // initial first, completed last, otherwise keep the ordering
                if s1.isInitial { return true }
                if s2.isInitial { return false }
                if s2.isCompleted { return true }
                if s1.isCompleted { return false }
                return true
            })
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

    private func setupHeaderStroke() {
        headerStroke.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)
    }

    private func setupTableView() {
        tableView.backgroundColor = view.backgroundColor
        tableView.sectionHeaderTopPadding = 0
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(ListViewCollaborationTableViewCell.self, forCellReuseIdentifier: "CollaborationCell")
        tableView.keyboardDismissMode = .onDrag
    }

    // TODO: 756
    /// updates shadow color based on the interface style and visibility based on the `bottomStrokeVisible`
    private func updateHeaderShadow() {
//        let shadowVisible = tableView.contentOffset.y > 0
//        if shadowVisible {
//            let darkMode = traitCollection.userInterfaceStyle == .dark
//            if darkMode {
//                sheetHeaderView.setShadowWithFigmaValues(x: 0, y: 6, blur: 10, opacity: 0.1)
//            } else {
//                sheetHeaderView.setShadowWithFigmaValues(x: 0, y: 3, blur: 6, opacity: 0.1)
//            }
//            // make the shadow height = 10 points, so the top part of the shadow is not visible
//            // (the path covers bottom part of the view only)
//            // This only works if the view is actually higher than 10 points. But if it's lower
//            // then the shadow with no shadowPath would not be shown (for view that has 0 height)
//            // so we still need to "cover" this view from top with another view (in a view that's
//            // adding this view controller as a child)
//            sheetHeaderView.layer.shadowPath = UIBezierPath(rect: CGRect(x: 0,
//                                                                         y: sheetHeaderView.bounds.maxY - 10,
//                                                                         width: sheetHeaderView.bounds.width,
//                                                                         height: 10)).cgPath
//        } else {
//            sheetHeaderView.layer.shadowOpacity = 0
//        }
    }
}

// MARK: table view delegate

extension ListViewCardViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        statuses.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if !expandedSections.contains(section) { return 0 }
        guard section < statuses.count else { return 0 }
        let status = statuses[section]
        return collaborationsByStatus[status]?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CollaborationCell",
                                                 for: indexPath) as! ListViewCollaborationTableViewCell
        if indexPath.section < statuses.count {
            let status = statuses[indexPath.section]
            if indexPath.row < collaborationsByStatus[status]?.count ?? 0,
               let collaboration = collaborationsByStatus[status]?[indexPath.row]
            {
                cell.setCollaboration(collaboration, projectTimeZone: projectModel.projectSummary.timeZone)
            }
        }
        return cell
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        headerFont.lineHeight + 2 * 5 + 2 * 10 // font height + statusView content insets + status view layout insets
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .dynamicColor(light: .Neutral_03, dark: .Neutral_08)
        let chevron =
            UIImageView(image: UIImage(systemName: "chevron.right",
                                       withConfiguration: UIImage.SymbolConfiguration(pointSize: 18)))
        chevron.contentMode = .center
        chevron.tintColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_05)
        chevron.tag = 999
        if expandedSections.contains(section) {
            chevron.transform = CGAffineTransform.identity.rotated(by: CGFloat.pi / 2)
        }
        view.addSubview(chevron)
        chevron.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
        }

        if section < statuses.count {
            let status = statuses[section]
            let statusView = StatusView()
            statusView.font = headerFont
            statusView.contentInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
            statusView.setStatus(status, count: collaborationsByStatus[status]?.count)
            view.addSubview(statusView)
            statusView.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview().inset(10)
                make.leading.equalTo(chevron.snp.trailing).offset(8)
            }
        }

        let stroke = UIView()
        stroke.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)
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

        let expanded = expandedSections.contains(section)
        let expand = !expanded
        if expand {
            expandedSections.insert(section)
        } else {
            expandedSections.remove(section)
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

        // TODO: 756
//        guard indexPath.section < items.count else { return }
//        guard let upload = items[indexPath.section].item as? Upload else { return }
//        UIApplication.shared.sendAction(
//            #selector(ProjectFlowActions.showFullscreenMediaAction),
//            to: nil,
//            from: self,
//            for: FlowEvent(upload)
//        )
    }
}
