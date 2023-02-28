import Foundation
import OSLog
import Realm
import RealmSwift
import UIKit

/// Card view controller presenting a list of tasks created by user, so user can select which task to copy.
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class CopyTaskCardViewController: SheetCardViewController {
    private let projectModel: ProjectModel

    private let collaborations: Results<Collaboration>
    private var uniqueCollaborations = [Collaboration]()
    /// Token for observing changes in collaborations
    private var notificationToken: NotificationToken?

    private let headerStroke = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)

    /// Callback for task selected, optional = nil when the selector was dismissed
    var onTaskSelected: ((Collaboration?) -> Void)?

    private var selectedTask: Collaboration?

    /// Initializer
    ///
    /// - Parameters:
    ///     - projectModel:               model to read collaborations from
    init(projectModel: ProjectModel, onTaskSelected: ((Collaboration?) -> Void)?) {
        self.projectModel = projectModel
        self.onTaskSelected = onTaskSelected
        collaborations = projectModel.mainRealm.objects(Collaboration.self)
            .where { (c: Query<Collaboration>) -> Query<Bool> in
                c.author == projectModel.currentUser && c.status != nil
            }
            .sorted(by: \Collaboration.timestamp, ascending: false)
        super.init(icon: UIImage(systemName: "mappin.and.ellipse"), title: String(localized: "Copy Task Pin"))
        onDismiss = { [weak self] in self?.onTaskSelected?(self?.selectedTask) }
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

        observeCollaborations()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // update the border color for cells
        tableView.reloadData()
        updateHeaderShadow()
    }

    private func observeCollaborations() {
        notificationToken = collaborations.observe { [weak self] (changes: RealmCollectionChange) in
            guard let self = self else { return }
            switch changes {
            case .initial:
                self.updateUniqueCollaborations()
                self.tableView.reloadData()
            case .update:
                self.updateUniqueCollaborations()
                self.tableView.reloadData()
            case let .error(error):
                Logger.model.error("observing collaborations failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Out of all collaborations select the ones that are unique with respect to name, description, dueDate, assignee and tags.
    /// The uniqueness is based on the values of all the fields combined to a one long string (to use the built-in uniqued function)
    private func updateUniqueCollaborations() {
        uniqueCollaborations = collaborations.uniqued { c in
            var values = [String]()
            values.append(c.name)
            if let description = c.collaborationDescription {
                values.append(description)
            }
            if let dueDate = c.dueDateTimestamp {
                values.append(String(dueDate.timeIntervalSince1970))
            }
            if let assignee = c.assignee {
                values.append(assignee.id)
            }
            for tag in c.tags {
                values.append(tag.id)
            }
            return String(values.joined(by: "_"))
        }
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
        tableView.register(CopyTaskTableViewCell.self, forCellReuseIdentifier: "TaskCell")
        tableView.keyboardDismissMode = .onDrag
    }

    /// updates shadow color based on the interface style and visibility based on the `bottomStrokeVisible`
    private func updateHeaderShadow() {
        let shadowVisible = tableView.contentOffset.y > 0
        if shadowVisible {
            let darkMode = traitCollection.userInterfaceStyle == .dark
            if darkMode {
                sheetHeaderView.setShadowWithFigmaValues(x: 0, y: 6, blur: 10, opacity: 0.1)
            } else {
                sheetHeaderView.setShadowWithFigmaValues(x: 0, y: 3, blur: 6, opacity: 0.1)
            }
            // make the shadow height = 10 points, so the top part of the shadow is not visible
            // (the path covers bottom part of the view only)
            // This only works if the view is actually higher than 10 points. But if it's lower
            // then the shadow with no shadowPath would not be shown (for view that has 0 height)
            // so we still need to "cover" this view from top with another view (in a view that's
            // adding this view controller as a child)
            sheetHeaderView.layer.shadowPath = UIBezierPath(rect: CGRect(x: 0,
                                                                         y: sheetHeaderView.bounds.maxY - 10,
                                                                         width: sheetHeaderView.bounds.width,
                                                                         height: 10)).cgPath
        } else {
            sheetHeaderView.layer.shadowOpacity = 0
        }
    }
}

// MARK: table view delegate

extension CopyTaskCardViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        uniqueCollaborations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TaskCell", for: indexPath) as! CopyTaskTableViewCell
        let index = indexPath.row
        if index < uniqueCollaborations.count {
            cell.setCollaboration(uniqueCollaborations[index], projectModel: projectModel)
        }
        cell.onCollaborationTapped = { [weak self] collaborationId in
            guard let self = self else { return }
            guard let collaboration = self.projectModel.mainRealm.object(
                ofType: Collaboration.self,
                forPrimaryKey: collaborationId
            ) else { return }
            self.selectedTask = collaboration
            self.dismissCard()
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        selectedTask = uniqueCollaborations[indexPath.row]
        dismissCard()
    }

    func scrollViewDidScroll(_: UIScrollView) {
        updateHeaderShadow()
    }
}
