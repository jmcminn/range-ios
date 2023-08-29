import Algorithms
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

    private var mostRecentUsedToggle: SegmentedControl!

    private let collaborations: Results<Collaboration>
    private var uniqueCollaborations = [Collaboration]()
    /// collaborations after making them unique and applying searchTerms
    private var searchedCollaborations: [Collaboration] = []

    /// for the "Most Used" tab, shown only the tasks that were used to copy task on this device, ordered so most recently used is at the top
    /// this is already filtered by searchTerms
    private var lastCopiedTasks: [Collaboration] = []

    /// Calculated from user search term input, this is what is actually applied to tasks.
    /// It's an array of case/diactric insensitive and trimmed components of the search term
    /// If empty then it counts as matched.
    private var searchTerms: [String] = []

    /// Token for observing changes in collaborations
    private var notificationToken: NotificationToken?

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var noTasksView: UIView?

    /// Callback for task selected
    var onTaskSelected: ((Collaboration) -> Void)?
    /// Callback when there were no tasks to copy and user selected "Add Task Pin" instead
    var onAddTaskPin: (() -> Void)?

    /// Initializer
    ///
    /// - Parameters:
    ///     - projectModel:               model to read collaborations from
    init(projectModel: ProjectModel) {
        self.projectModel = projectModel
        collaborations = projectModel.mainRealm.objects(Collaboration.self)
            .where { (c: Query<Collaboration>) -> Query<Bool> in
                c.status != nil
            }
            .sorted(by: \Collaboration.timestamp, ascending: false)

        super.init(
            icon: UIImage(systemName: "mappin.and.ellipse"),
            title: String(localized: "Select Task to Copy"),
            showSearchView: true
        )
    }

    deinit {
        notificationToken?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addSheetHeaderStroke()
        addSheetHeaderShadowBasedOnDrivingScrollView()

        setupSearchView()
        setupMostRecentUsedToggle()

        setupTableView()
        containerView.insertSubview(tableView, belowSubview: sheetHeaderView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        observeCollaborations()
        updateNoTasksViewVisibility()
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

    /// Define String value based on Collaboration name, description, dueDate, assignee and tags.
    /// The Copy task card only display collaborations that are unique with respect to this value.
    private func uniqueProjection(_ collaboration: Collaboration) -> String {
        var values = [String]()
        values.append(collaboration.name)
        if let description = collaboration.collaborationDescription {
            values.append(description)
        }
        if let dueDate = collaboration.dueDateTimestamp {
            values.append(String(dueDate.timeIntervalSince1970))
        }
        // if assignee is not active then ignore it (we don't copy inactive assignees)
        if let assignee = collaboration.assignee, assignee.participation == .active {
            values.append(assignee.id)
        }
        for tag in collaboration.tags {
            values.append(tag.id)
        }
        return String(values.joined(by: "_"))
    }

    /// Out of all collaborations select the ones that are unique with respect to name, description, dueDate, assignee and tags.
    /// The uniqueness is based on the values of all the fields combined to a one long string (to use the built-in uniqued function)
    /// Then filter the collaboration by searchTerms
    private func updateData() {
        uniqueCollaborations = collaborations.uniqued(on: uniqueProjection)
        searchedCollaborations = uniqueCollaborations.filter(matchSearchTerms)

        // last copied tasks need to filter by UserDefaults.lastCopiedTasks first and then apply
        // .uniqued, otherwise .uniqued may filter out the task ids from lastCopiedTasks and prefer
        // the task with same data but different it...
        lastCopiedTasks =
            UserDefaults.lastCopiedTasks(forProjectId: projectModel.projectId).compactMap { taskId in
                collaborations.first { $0.id == taskId }
            }
            .uniqued(on: uniqueProjection)
            .filter(matchSearchTerms)

        updateNoTasksViewVisibility()

        tableView.reloadData()
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        let baseHeight = super.height(forContainer: cardContainerView, cardPosition: cardPosition)
        if cardPosition == .max {
            if uniqueCollaborations.isEmpty {
                view.layoutIfNeeded()
                return baseHeight + (noTasksView?.frame.height ?? 0.0)
            } else {
                // just make it max, so it doesn't depend on the content height
                return Double.greatestFiniteMagnitude
            }
        } else {
            return baseHeight
        }
    }

    override func drivingScrollView() -> UIScrollView? {
        tableView
    }

    private func setupSearchView() {
        searchView.placeholderText = String(localized: "Search")
        searchView.addDelegate(self)
    }

    private func setupMostRecentUsedToggle() {
        mostRecentUsedToggle = SegmentedControl(items: [
            ActionItem(
                title: String(localized: "Most Recent"),
                handler: { [weak self] in
                    self?.tableView.reloadData()
                }
            ),
            ActionItem(
                title: String(localized: "Most Used"),
                handler: { [weak self] in
                    self?.tableView.reloadData()
                }
            ),
        ])
        addSheetHeaderSubview(mostRecentUsedToggle)
        mostRecentUsedToggle.snp.makeConstraints { make in
            make.height.equalTo(SegmentedControl.height)
        }
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
}

// MARK: table view delegate

extension CopyTaskCardViewController: UITableViewDelegate, UITableViewDataSource {
    var tasksToDisplay: [Collaboration] {
        // display all or last copied depending on the current toggle selection
        if mostRecentUsedToggle.selectedSegmentIndex == 0 {
            return searchedCollaborations
        } else {
            return lastCopiedTasks
        }
    }

    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        tasksToDisplay.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TaskCell", for: indexPath) as! CopyTaskTableViewCell
        let index = indexPath.row
        if index < tasksToDisplay.count {
            cell.setCollaboration(tasksToDisplay[index], projectModel: projectModel)
        }
        cell.onCollaborationTapped = { [weak self] collaborationId in
            guard let self = self else { return }
            guard let collaboration = self.projectModel.mainRealm.object(
                ofType: Collaboration.self,
                forPrimaryKey: collaborationId
            ) else { return }
            self.onTaskSelected?(collaboration)
            self.dismissCard()
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let selectedTask = tasksToDisplay[indexPath.row]
        onTaskSelected?(selectedTask)
        dismissCard()
    }
}

// MARK: - no tasks view

extension CopyTaskCardViewController {
    private func updateNoTasksViewVisibility() {
        let showNoTasks = uniqueCollaborations.isEmpty
        if showNoTasks {
            if noTasksView == nil {
                setupNoTasksView()
            }
            noTasksView?.isHidden = false
        } else {
            noTasksView?.isHidden = true
        }
        if let cardDragging = cardDragging {
            // animate the card to adjust for no tasks visibility
            cardDragging.setPosition(cardDragging.position, withVelocity: 0)
        }
    }

    private func setupNoTasksView() {
        let view = UIView()
        view.backgroundColor = .dynamic(.Neutral_09)

        let questionPin = UIImageView(image: UIImage(named: "large_question_pin"))
        view.addSubview(questionPin)
        questionPin.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(58)
            make.centerX.equalToSuperview()
        }
        let titleLabel = UILabel()
        titleLabel.font = ._preferredFont(forTextStyle: .title3, symbolicTraits: .traitBold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .dynamic(.Neutral_04)
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.text = String(localized: "There are no tasks to copy...")
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(questionPin.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(36)
        }
        let descriptionLabel = UILabel()
        descriptionLabel.font = .preferredFont(forTextStyle: .body)
        descriptionLabel.adjustsFontForContentSizeCategory = true
        descriptionLabel.textColor = .dynamic(.Neutral_05)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center
        descriptionLabel
            .text = String(localized: "In order to copy an existing task, you need to add a task pin first.")
        view.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(36)
        }

        let addTaskPinButton = UIButton(
            configuration: UIButton.Configuration.blueButton(horizontalInsets: 32),
            primaryAction: UIAction(title: String(localized: "Add Task Pin")) { [weak self] _ in
                self?.onAddTaskPin?()
                self?.dismissCard()
            }
        )
        view.addSubview(addTaskPinButton)
        addTaskPinButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(descriptionLabel.snp.bottom).offset(24)
            make.bottom.equalToSuperview().inset(58)
        }

        let bottomStroke = UIView()
        bottomStroke.backgroundColor = .dynamic(.Neutral_07)
        view.addSubview(bottomStroke)
        bottomStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }

        containerView.addSubview(view)
        view.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }

        noTasksView = view
    }
}

// MARK: - filtering tasks by search term

extension CopyTaskCardViewController: SearchViewDelegate {
    func searchView(_: SearchView, textDidChange text: String) {
        // calculate search terms from user entered search text
        let textTrimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // remove diacritics and make it lowercase
        let searchTerm = textTrimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        // split by whitespace to multiple terms
        searchTerms = searchTerm.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        updateData()
    }

    /// Collaboration matches if its name contains all the searchTerms
    func matchSearchTerms(collaboration: Collaboration) -> Bool {
        guard !searchTerms.isEmpty else { return true }
        let name = collaboration.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let tagNames = collaboration.tags.map {
            $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        }
        // all of the search terms must be found either in name or any tag name
        return searchTerms.allSatisfy { searchTerm in
            if name.contains(searchTerm) { return true }
            for tagName in tagNames {
                if tagName.contains(searchTerm) { return true }
            }
            return false
        }
    }
}
