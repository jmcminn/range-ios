import Foundation
import OSLog
import Realm
import RealmSwift
import UIKit

/// Card view controller presenting a list of tasks.
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class TaskListCardViewController: SheetCardViewController {
    /// The mode in which the task list is currently operating
    private enum Mode {
        case normal // showing tasks
        case select // selecting tasks
    }

    private let projectModel: ProjectModel
    unowned let canvasContainer: CanvasContainerViewController

    private let headerView = UIView()
    private let searchView: SearchView
    private let headerStroke = UIView()

    private let tableView = UITableView(frame: .zero, style: .plain)

    // all collaborations
    private let collaborations: Results<Collaboration>
    // collaborations after applying the filters
    private var filteredCollaborations: [Collaboration] = []
    // collaborations after applying the filters and searchTerm
    private var searchedCollaborations: [Collaboration] = []

    /// Calculated from user search term input, this is what is actually applied to tasks.
    /// It's an array of case/diactric insensitive and trimmed components of the search term
    /// If empty then it counts as matched.
    private var searchTerms: [String] = []

    private var emptyView: UIView?
    private var emptyFilteredView: UIView?

    /// Token for observing changes in collaborations
    private var notificationToken: NotificationToken?

    private let filters: TaskListFilters
    private let filtersButton = RoundShadowButton(image: UIImage(named: "filter.search") ?? UIImage())
    private let filtersIndicatorBadge = BadgeView()

    private var selectButton: ButtonWithTapAreaInsets!
    private var mode: Mode = .normal

    /// ids of selected uploads
    private var selectedTasks = Set<String>()

    private var bulkActionsBottomBar: UIView?
    private var selectedTasksCountLabel: UILabel?
    private var bulkActionsButton: UIButton?

    /// Initializer
    ///
    /// - Parameters:
    ///     - projectModel:               model to read collaborations from
    init(projectModel: ProjectModel, canvasContainer: CanvasContainerViewController) {
        self.projectModel = projectModel
        self.canvasContainer = canvasContainer
        filters = TaskListFilters(model: projectModel)
        collaborations = projectModel.mainRealm.objects(Collaboration.self)
            .where { (c: Query<Collaboration>) -> Query<Bool> in
                c.placeholder == false && c.status != nil // only tasks
            }
        searchView = SearchView(placeholderText: "Search", showClearButton: true)

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
            make.height.equalTo(56)
        }

        setupSelectButton()

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
        searchedCollaborations = filteredCollaborations.filter(matchSearchTerms)
        reloadSelectedTasks()

        tableView.reloadData()

        onCollaborationsChanged()
    }

    /// Called after tasks were updated, some tasks might be gone, so they're no longer selected
    private func reloadSelectedTasks() {
        let newTasks = Set<String>(filteredCollaborations.map(\.id))
        // Update the selectedTasks and remove all no longer existing tasks
        selectedTasks.formIntersection(newTasks)
    }

    /// Adjust the UI for changed collaborations
    private func onCollaborationsChanged() {
        updateBulkActionsBottomBarVisibility()
        updateSelectedTasksCountLabel()
        updateFiltersIndicatorBadge()

        let emptyTasks = collaborations.isEmpty
        let emptyFilteredTasks = filteredCollaborations.isEmpty

        filtersButton.isHidden = emptyTasks
        selectButton.isHidden = emptyTasks

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

        searchView.addDelegate(self)
        headerView.addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(40)
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
        tableView.register(
            TaskListCollaborationTableViewCell.self,
            forCellReuseIdentifier: TaskListCollaborationTableViewCell.Variant.identifier(forSelectable: false)
        )
        tableView.register(
            TaskListCollaborationTableViewCell.self,
            forCellReuseIdentifier: TaskListCollaborationTableViewCell.Variant.identifier(forSelectable: true)
        )
        tableView.keyboardDismissMode = .onDrag
        tableView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress)))
    }

    private func setupSelectButton() {
        guard selectButton == nil else { return }
        var config = UIButton.Configuration.filled()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        config.baseBackgroundColor = .dynamic(.Neutral_09)
        config.baseForegroundColor = .dynamic(.Neutral_04)
        config.cornerStyle = .fixed
        config.background.cornerRadius = 15
        config.background.strokeColor = .dynamic(.Neutral_07)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: .subheadline)
            return outgoing
        }
        selectButton = ButtonWithTapAreaInsets(
            configuration: config,
            primaryAction: UIAction(title: String(localized: "Select")) { [weak self] _ in
                self?.toggleMode()
            }
        )
        // more vertical tap area as button is only 30 points high
        selectButton.tapAreaInsets = UIEdgeInsets(top: -10, left: 0, bottom: -10, right: 0)

        sheetHeaderView.addSubview(selectButton)
        selectButton.snp.makeConstraints { make in
            make.centerY.equalTo(closeButton)
            make.trailing.equalTo(closeButton.snp.leading).offset(-8)
            make.height.equalTo(30)
        }
    }

    private func toggleMode() {
        mode = mode == .normal ? .select : .normal
        selectButton.setTitle(mode == .normal ? String(localized: "Select") : String(localized: "Cancel"),
                              for: .normal)
        selectedTasks.removeAll()
        tableView.reloadData()
        updateBulkActionsBottomBarVisibility()
        updateSelectedTasksCountLabel()
    }
}

// MARK: table view delegate

extension TaskListCardViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        searchedCollaborations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: TaskListCollaborationTableViewCell.Variant.identifier(forSelectable: mode == .select),
            for: indexPath
        ) as! TaskListCollaborationTableViewCell
        if indexPath.row < searchedCollaborations.count {
            let collaboration = searchedCollaborations[indexPath.row]
            cell.setCollaboration(collaboration, projectTimeZone: projectModel.projectSummary.timeZone)
            cell.mark(selected: selectedTasks.contains(collaboration.id))
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

        guard indexPath.row < searchedCollaborations.count else { return }
        let collaboration = searchedCollaborations[indexPath.row]

        if mode == .normal {
            UIApplication.shared.sendAction(
                #selector(ProjectFlowActions.showCollaborationAction),
                to: nil,
                from: self,
                for: FlowEvent(collaboration)
            )
        } else {
            toggleSelectionAndUpdateUI(forIndexPath: indexPath)
        }
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

// MARK: - selection

extension TaskListCardViewController {
    /// Handle long press on cells - enabled select mode if not enabled and select given cell
    @objc func handleLongPress(gesture: UILongPressGestureRecognizer!) {
        guard gesture.state == .began else { return }

        let point = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point) else { return }

        // enable select mode if in normal mode
        if mode == .normal {
            toggleMode()
        }
        // handle selection/deselection
        toggleSelectionAndUpdateUI(forIndexPath: indexPath)
    }

    /// Marks the indexPath cell as selected and add/remove to selectedTasks
    private func markIndexPath(_ indexPath: IndexPath, selected: Bool) {
        guard indexPath.row < searchedCollaborations.count else { return }
        let id = searchedCollaborations[indexPath.row].id
        if selected {
            selectedTasks.insert(id)
        } else {
            selectedTasks.remove(id)
        }
        if let cell = tableView.cellForRow(at: indexPath) as? TaskListCollaborationTableViewCell {
            cell.mark(selected: selected)
        }
    }

    private func updateSelectedTasksCountLabel() {
        selectedTasksCountLabel?.text = selectedTasksCountText
    }

    var selectedTasksCountText: String {
        let numberOfItems = selectedTasks.count
        return (numberOfItems == 1)
            ? String(localized: "1x task selected")
            : String(localized: "\(numberOfItems)x tasks selected")
    }

    /// Toggle the selection for task at given indexPath and update all relevant UI elements (bottom bar)
    private func toggleSelectionAndUpdateUI(forIndexPath indexPath: IndexPath) {
        guard indexPath.row < searchedCollaborations.count else { return }
        let task = searchedCollaborations[indexPath.row]
        let selected = !selectedTasks.contains(task.id)
        markIndexPath(indexPath, selected: selected)
        updateBulkActionsBottomBarVisibility()
        updateSelectedTasksCountLabel()
    }
}

// MARK: - bulk actions

extension TaskListCardViewController {
    private func setupBulkActionsBottomBar() {
        guard bulkActionsBottomBar == nil else { return }
        let bottomBar = UIView()
        bottomBar.backgroundColor = .clear

        let blurEffect = UIBlurEffect(style: .regular)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.isUserInteractionEnabled = false
        bottomBar.addSubview(blurEffectView)
        blurEffectView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalToSuperview().offset(100) // add some for the bottom safe area
        }

        let stroke = UIView()
        stroke.backgroundColor = .dynamic(.Neutral_07)
        bottomBar.addSubview(stroke)
        stroke.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(1)
        }

        let countLabel = UILabel()
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.textColor = .dynamic(.Neutral_04)
        countLabel.font = ._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold)
        bottomBar.addSubview(countLabel)
        countLabel.snp.makeConstraints { make in
            make.centerY.equalTo(bottomBar.snp.top).offset(36)
            make.leading.equalToSuperview().inset(16)
        }

        let button = UIButton(
            configuration: UIButton.Configuration.blueButton(),
            primaryAction: UIAction(
                image: UIImage(systemName: "ellipsis")
            ) { [weak self] _ in self?.showBulkActions() }
        )

        bottomBar.addSubview(button)
        button.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview().inset(16)
            make.width.height.equalTo(40)
        }
        containerView.addSubview(bottomBar)
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(containerView.snp.bottom)
        }

        bulkActionsBottomBar = bottomBar
        bulkActionsButton = button
        selectedTasksCountLabel = countLabel
        containerView.layoutIfNeeded()
    }

    /// show or hide the bottom bar for bulk actions button
    private func updateBulkActionsBottomBarVisibility() {
        let shouldHide = selectedTasks.isEmpty
        if shouldHide {
            if let bottomBar = bulkActionsBottomBar {
                bottomBar.snp.remakeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.top.equalTo(bottomBar.superview!.snp.bottom)
                }
                filtersButton.snp.remakeConstraints { make in
                    make.trailing.equalToSuperview().inset(12)
                    make.bottom.equalTo(containerView.safeAreaLayoutGuide.snp.bottom).offset(-12)
                }
                UIView.animate(withDuration: 0.2) { [weak self] in
                    self?.containerView.layoutIfNeeded()
                }
            }
            tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            tableView.scrollIndicatorInsets = tableView.contentInset
        } else {
            setupBulkActionsBottomBar()
            if let bottomBar = bulkActionsBottomBar {
                bottomBar.snp.remakeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
                }
                filtersButton.snp.remakeConstraints { make in
                    make.trailing.equalToSuperview().inset(12)
                    make.bottom.equalTo(bottomBar.snp.top).offset(-12)
                }
                UIView.animate(withDuration: 0.2) { [weak self] in
                    self?.containerView.layoutIfNeeded()
                } completion: { [weak self] _ in
                    guard let self = self else { return }
                    self.tableView.contentInset = UIEdgeInsets(
                        top: 0,
                        left: 0,
                        bottom: bottomBar.frame.height,
                        right: 0
                    )
                    self.tableView.scrollIndicatorInsets = self.tableView.contentInset
                }
            }
        }
    }

    private func showBulkActions() {
        ActionSelectorCardViewController(
            icon: UIImage(systemName: "ellipsis"),
            title: String(localized: "Bulk Actions"),
            subtitle: "(\(selectedTasksCountText))",
            actions: [
                ActionItem(title: String(localized: "Tags"), imageName: "tag",
                           handler: { [weak self] in self?.presentBulkManageTagsCard() }),
                ActionItem(title: String(localized: "Due Date"), imageName: "calendar",
                           handler: { [weak self] in self?.presentBulkUpdateDueDateCard() }),
                ActionItem(title: String(localized: "Assignee"), imageName: "person",
                           handler: { [weak self] in self?.presentBulkUpdateAssigneeCard() }),
                ActionItem(title: String(localized: "Status"), imageName: "circle.dashed",
                           handler: { [weak self] in self?.presentBulkUpdateStatusCard() }),
            ]
        ).installAndShowCard(in: canvasContainer)
    }

    private func presentBulkManageTagsCard() {
        let tagsViewModel = TagsViewModel(model: projectModel)

        let addTagsOptionText = String(localized: "Add additional, new tags to the selected tasks.")
        let replaceTagsOptionText = String(localized:
            "Replace ALL existing tags with new tags for the selected tasks. ALL existing tags will be removed and replaced with new tags.")

        let tagsVC = SearchAndSelectTagsViewController(tagsViewModel: tagsViewModel, autoDismissCard: false)
        tagsVC.showCancelConfirmBottomBar = true
        tagsVC.showOptions(
            [ActionItem(title: String(localized: "Add Tags"), handler: { [weak tagsVC] in
                tagsVC?.setOptionLabel(addTagsOptionText)
            }),
            ActionItem(title: String(localized: "Replace Tags"), handler: { [weak tagsVC] in
                tagsVC?.setOptionLabel(replaceTagsOptionText)
            })]
        )
        tagsVC.setOptionLabel(addTagsOptionText)

        // block to run for confirming the changes and dismissing the card
        let onConfirm = { [weak self, weak tagsVC] in
            // add or replace depending on the option selected in tagsVC (adding is the first option)
            let addTags: Bool = (tagsVC?.optionsToggle?.selectedSegmentIndex ?? 0) == 0
            self?.bulkUpdateTags(tagsViewModel, add: addTags)
            tagsVC?.dismissCard()
        }
        // block to run when user has unsaved changes and chose to close the card - ask if he wants to cancel or save
        let onUnsavedChanges = { [weak tagsVC] in
            guard let tagsVC = tagsVC else { return }
            // user selected some tags, confirm if closing should apply the changes
            let alertController = UIAlertController(
                title: "You have unsaved changes",
                message: "Would you like to confirm or cancel these changes?",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                tagsVC.dismissCard()
            })
            alertController.addAction(UIAlertAction(title: "Confirm", style: .default) { _ in
                onConfirm()
            })
            tagsVC.present(alertController, animated: true)
        }

        // when closing check if user selected any tasks and confirm if so
        tagsVC.onClose = { [weak tagsVC] in
            if tagsViewModel.selectedTags.isEmpty {
                tagsVC?.dismissCard()
            } else {
                onUnsavedChanges()
            }
        }
        // always dismiss on cancel
        tagsVC.onCancel = { [weak tagsVC] in tagsVC?.dismissCard() }
        // apply changes on confirm
        tagsVC.onConfirm = onConfirm

        tagsVC.installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    private func bulkUpdateTags(_ tagsModel: TagsViewModel, add: Bool) {
        projectModel.run(
            projectModel.update(tags: tagsModel.selectedTags, forCollaborations: [String](selectedTasks), add: add)
        ) { error in
            if error != nil { ToastWindow.shared.showError(text: "Failed to update tags") }
        }
    }

    private func presentBulkUpdateDueDateCard() {
        DatePickerCardViewController(
            title: "Due Date",
            timeZone: projectModel.projectSummary.timeZone,
            initialSelectedDate: nil, // no initial date as it's a bulk operation
            showRemoveDateOption: true, // but still allow to clear the date for all tasks
            onDatePicked: { [weak self] date in
                self?.bulkUpdateDueDate(date)
            }
        )
        .installAndShowCard(in: self)
    }

    private func bulkUpdateDueDate(_ date: Date?) {
        projectModel.run(
            projectModel.update(dueDate: date, forCollaborations: [String](selectedTasks))
        ) { error in
            if error != nil { ToastWindow.shared.showError(text: "Failed to update the due date") }
        }
    }

    private func presentBulkUpdateAssigneeCard() {
        let viewModel = UsersViewModel(model: projectModel, multiselect: false)
        let userPicker = UserPickerCardViewController(title: "Assignee", viewModel: viewModel)
        // add option to clear current assignee
        userPicker.showNoUserOption = true
        userPicker.onClose = { [weak self] in
            let newAssigneeId = viewModel.selectedUsers.first?.id
            self?.bulkUpdateAssignee(newAssigneeId)
        }
        userPicker.installAndShowCard(in: self)
    }

    private func bulkUpdateAssignee(_ assigneeId: String?) {
        projectModel.run(
            projectModel.update(assigneeId: assigneeId, forCollaborations: [String](selectedTasks))
        ) { error in
            if error != nil { ToastWindow.shared.showError(text: "Failed to update the assignee") }
        }
    }

    private func presentBulkUpdateStatusCard() {
        let statuses = [Status](projectModel.mainRealm.objects(Status.self).sorted(by: Status.uiSortingOrder))
        StatusPickerCardViewController(
            title: "Assign Status",
            statuses: statuses,
            selectedStatus: nil,
            onStatusPicked: { [weak self] newStatus in
                self?.bulkUpdateStatus(newStatus)
            }
        )
        .installAndShowCard(in: self)
    }

    private func bulkUpdateStatus(_ status: Status) {
        projectModel.run(
            projectModel.update(status: status, forCollaborations: [String](selectedTasks))
        ) { error in
            if error != nil { ToastWindow.shared.showError(text: "Failed to update the status") }
        }
    }
}

// MARK: - empty state

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

// MARK: - filtering tasks by search term

extension TaskListCardViewController: SearchViewDelegate {
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
        return searchTerms.allSatisfy { name.contains($0) }
    }
}
