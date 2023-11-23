import Combine
import Foundation
import RealmSwift
import UIKit

/// Card view controller presenting filters for task list
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class TaskListFiltersCardViewController: SheetCardViewController {
    unowned let model: ProjectModel
    private let filters: TaskListFilters
    private let statuses: [Status]
    private let usersViewModel: UsersViewModel
    private let canvasesViewModel: CanvasesViewModel
    private let tagsViewModel: TagsViewModel

    private var resetButton: RangeButton!

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private var assigneeFilterTypeToggle: SegmentedControl!
    private let showCreatedInLastNDaysSwitch = UISwitch()
    private let dateCreatedSelectorView: OptionSelectorCollectionView
    private let showUpdatedInLastNDaysSwitch = UISwitch()
    private let dateUpdatedSelectorView: OptionSelectorCollectionView
    private let usersView: SelectedUsersView
    private let filterByCanvasSwitch = UISwitch()
    private let canvasesView: SelectedCanvasesView
    private var statusLabels = [Status: UILabel]()
    private var statusSwitches = [Status: UISwitch]()
    private let filterByTagsSwitch = UISwitch()
    private let tagsView: SelectedTagsView
    private let showOnlyOverdueSwitch = UISwitch()
    private let showOnlyCreatedByUserSwitch = UISwitch()
    private let showArchivedSwitch = UISwitch()

    private var gradientViews = [GradientView]()

    /// Initializer
    ///
    /// - Parameters:
    ///     - filters:                         TaskListFilters
    init(model: ProjectModel, taskListFilters filters: TaskListFilters) {
        self.model = model
        self.filters = filters

        dateCreatedSelectorView = OptionSelectorCollectionView(
            options: DateOptions.buildOptionItems(DateOptions.defaultDaysOptions) { days in
                filters.showCreatedInLastNDays = days
            }
        )
        dateCreatedSelectorView.selectedItem = filters.showCreatedInLastNDays != nil
            ? DateOptions.defaultDaysOptions.firstIndex(of: filters.showCreatedInLastNDays!)
            : nil

        dateUpdatedSelectorView = OptionSelectorCollectionView(
            options: DateOptions.buildOptionItems(DateOptions.defaultDaysOptions) { days in
                filters.showUpdatedInLastNDays = days
            }
        )
        dateUpdatedSelectorView.selectedItem = filters.showUpdatedInLastNDays != nil
            ? DateOptions.defaultDaysOptions.firstIndex(of: filters.showUpdatedInLastNDays!)
            : nil

        statuses = (model.mainRealm.objects(Status.self).sorted(by: Status.uiSortingOrder))

        let usersViewModel = UsersViewModel(model: model, multiselect: true, showSuspendedUsers: true)
        // preselect users from filters
        filters.assigneeFilter?.forEach { usersViewModel.set(userWithId: $0, selected: true) }
        usersView = SelectedUsersView(viewModel: usersViewModel, showEditUserCell: true)
        self.usersViewModel = usersViewModel

        let canvasesViewModel = CanvasesViewModel(model: model, multiselect: true)
        // preselect canvases from filters
        filters.canvasFilter?.forEach { canvasesViewModel.set(canvasWithId: $0, selected: true) }
        canvasesView = SelectedCanvasesView(viewModel: canvasesViewModel, showEditCell: true)
        self.canvasesViewModel = canvasesViewModel

        let tagsViewModel = TagsViewModel(model: model)
        // preselect tags from the filter
        filters.tagsFilter?.forEach { tagsViewModel.set(tagWithId: $0, selected: true) }
        tagsView = SelectedTagsView(viewModel: tagsViewModel, showEditTagCell: true)
        self.tagsViewModel = tagsViewModel

        super.init(
            icon: UIImage(named: "filter.search"),
            title: String(localized: "Task List Filters"),
            subtitle: "tasks in the list"
        )

        let assigneeFilterTypeActionItems = TaskListFilters.AssigneeFilterType.allCases.map { assigneeFilterType in
            ActionItem(title: assigneeFilterType.displayName) { [weak self] in
                guard let self = self else { return }
                self.filters.assigneeFilterType = assigneeFilterType
                self.onAssigneeFilterTypeChanged()
            }
        }
        assigneeFilterTypeToggle = SegmentedControl(items: assigneeFilterTypeActionItems)

        usersViewModel.addDelegate(self)
        tagsViewModel.addDelegate(self)
        canvasesViewModel.addDelegate(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addSheetHeaderStroke()
        addSheetHeaderShadowBasedOnDrivingScrollView()

        setupResetButton()

        filterByCanvasSwitch.addAction(.init(handler: { [weak self] _ in
            self?.onFilterByCanvasSwitchAction()
        }), for: .valueChanged)

        // add a switch per status
        for status in statuses {
            let statusSwitch = UISwitch()
            statusSwitch.addAction(.init(handler: { [weak self] action in
                guard let sender = action.sender as? UISwitch else { return }
                self?.filters.set(status, shown: sender.isOn)
            }), for: .valueChanged)
            statusSwitches[status] = statusSwitch
            statusLabels[status] = createLabel(text: status.name)
        }

        setupViews()

        showCreatedInLastNDaysSwitch.addAction(.init(handler: { [weak self] _ in
            guard let self = self else { return }
            self.dateCreatedSelectorView.isHidden = !self.showCreatedInLastNDaysSwitch.isOn
            if !self.showCreatedInLastNDaysSwitch.isOn {
                self.filters.showCreatedInLastNDays = nil
                self.dateCreatedSelectorView.selectedItem = nil
            }
        }), for: .valueChanged)
        showUpdatedInLastNDaysSwitch.addAction(.init(handler: { [weak self] _ in
            guard let self = self else { return }
            self.dateUpdatedSelectorView.isHidden = !self.showUpdatedInLastNDaysSwitch.isOn
            if !self.showUpdatedInLastNDaysSwitch.isOn {
                self.filters.showUpdatedInLastNDays = nil
                self.dateUpdatedSelectorView.selectedItem = nil
            }
        }), for: .valueChanged)
        filterByTagsSwitch.addAction(.init(handler: { [weak self] _ in
            self?.onFilterByTagsSwitchAction()
        }), for: .valueChanged)

        showOnlyOverdueSwitch.addAction(.init(handler: { [weak self] _ in
            self?.filters.showOnlyOverdue.toggle()
        }), for: .valueChanged)

        showOnlyCreatedByUserSwitch.addAction(.init(handler: { [weak self] _ in
            self?.filters.showOnlyCreatedByUser.toggle()
        }), for: .valueChanged)

        showArchivedSwitch.addAction(.init(handler: { [weak self] _ in
            self?.filters.showArchived.toggle()
        }), for: .valueChanged)

        updateControlsStateFromFilters()
        updateColors()
    }

    private func updateControlsStateFromFilters() {
        let assigneeFilterTypeToggleOptionIndex = TaskListFilters.AssigneeFilterType.allCases
            .lastIndex(of: filters.assigneeFilterType) ?? 0
        assigneeFilterTypeToggle.setSelectedSegmentIndex(assigneeFilterTypeToggleOptionIndex, animated: true)
        showCreatedInLastNDaysSwitch.setOn(filters.showCreatedInLastNDays != nil, animated: false)
        dateCreatedSelectorView.isHidden = !showCreatedInLastNDaysSwitch.isOn
        showUpdatedInLastNDaysSwitch.setOn(filters.showUpdatedInLastNDays != nil, animated: false)
        dateUpdatedSelectorView.isHidden = !showUpdatedInLastNDaysSwitch.isOn
        filterByCanvasSwitch.setOn(filters.canvasFilter != nil, animated: false)
        for status in statuses {
            if let statusSwitch = statusSwitches[status] {
                statusSwitch.setOn(filters.show(status), animated: false)
            }
        }
        filterByTagsSwitch.setOn(filters.tagsFilter != nil, animated: false)
        showOnlyCreatedByUserSwitch.setOn(filters.showOnlyCreatedByUser, animated: false)
        showOnlyOverdueSwitch.setOn(filters.showOnlyOverdue, animated: false)
        showArchivedSwitch.setOn(filters.showArchived, animated: false)
        usersView.setVisible(filters.assigneeFilterType == .select, animated: false)
        canvasesView.setVisible(filters.canvasFilter != nil, animated: false)
        tagsView.setVisible(filters.tagsFilter != nil, animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(
            self, selector: #selector(filtersUpdated),
            name: TaskListFilters.UpdateNotificationName, object: nil
        )
        filtersUpdated()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    @objc func filtersUpdated() {
        resetButton.isHidden = filters.hasDefaultValues

        let tasksCount = model.mainRealm.objects(Collaboration.self)
            .where { (c: Query<Collaboration>) -> Query<Bool> in
                c.placeholder == false && c.status != nil // only tasks
            }
            .filter(filters.match) // apply filter
            .count
        subtitleLabel?.text = tasksCount == 1
            ? String(localized: "1 task in the list")
            : String(localized: "\(tasksCount) tasks in the list")
    }

    private func setupViews() {
        // Scroll view setup
        scrollView.alwaysBounceVertical = true
        containerView.insertSubview(scrollView, belowSubview: sheetHeaderView)
        scrollView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.bottom.equalToSuperview().inset(12)
        }

        // Stack view setup
        stackView.axis = .vertical
        stackView.layer.cornerRadius = 13
        stackView.layer.borderWidth = 1
        stackView.backgroundColor = .dynamic(.Neutral_09)
        scrollView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.bottom.leading.trailing.equalToSuperview().inset(16)
        }

        // ----- Assignee --------------------------------------------------------------------------
        add(label: createLabel(text: String(localized: "Filter by Assignee")), bottomInset: 13)
        addAssigneeFilterTypeView()
        addUsersView()
        addSpace(height: 9)
        addSeparator()

        // ----- Tasks created in the last ... -----------------------------------------------------
        add(label: createLabel(text: String(localized: "Show tasks created in the...")),
            control: showCreatedInLastNDaysSwitch,
            bottomInset: 4) // the rest = 9 is added below the selection view
        addDateCreatedSelectorView()
        addSpace(height: 9)
        addSeparator()

        // ----- Tasks updated in the last ... -----------------------------------------------------
        add(label: createLabel(text: String(localized: "Show tasks updated in the...")),
            control: showUpdatedInLastNDaysSwitch,
            bottomInset: 4) // the rest = 9 is added below the selection view
        addDateUpdatedSelectorView()
        addSpace(height: 9)
        addSeparator()

        // ----- Statuses --------------------------------------------------------------------------
        add(label: createLabel(text: String(localized: "Filter by Status")), bottomInset: 5)
        for (index, status) in statuses.enumerated() {
            if let statusLabel = statusLabels[status], let statusSwitch = statusSwitches[status] {
                add(label: statusLabel, control: statusSwitch, topInset: index == 0 ? 13 : 5,
                    bottomInset: index == (statuses.count - 1) ? 13 : 5)
            }
        }
        addSeparator()

        // ----- Overdue tasks ---------------------------------------------------------------------
        add(label: createLabel(text: String(localized: "Only show overdue tasks")), control: showOnlyOverdueSwitch)
        addSeparator()

        // ----- Canvas ----------------------------------------------------------------------------
        add(label: createLabel(text: String(localized: "Filter by Canvas")),
            control: filterByCanvasSwitch,
            bottomInset: 4) // the rest = 9 is added below canvases view
        addCanvasesView()
        addSpace(height: 9)
        addSeparator()

        // ----- Tags ------------------------------------------------------------------------------
        add(label: createLabel(text: String(localized: "Filter by Tags")), control: filterByTagsSwitch,
            bottomInset: 4) // the rest = 9 is added below tags view
        addTagsView()
        addSpace(height: 9)
        addSeparator()

        // ----- Tasks I've created ----------------------------------------------------------------
        add(label: createLabel(text: String(localized: "Only show tasks I've created")),
            control: showOnlyCreatedByUserSwitch)
        addSeparator()

        // ----- Archived pins ---------------------------------------------------------------------
        add(label: createLabel(text: String(localized: "Show Archived tasks")), control: showArchivedSwitch)
    }

    /// Adds given label to the stack view with proper insets
    private func add(label: UILabel, topInset: Double = 13, bottomInset: Double = 13) {
        // wrapper to add leading/trailing insets
        let wrapper = UIView()
        wrapper.addSubview(label)
        stackView.addArrangedSubview(wrapper)
        label.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(topInset)
            make.bottom.equalToSuperview().inset(bottomInset)
            make.leading.trailing.equalToSuperview().inset(16)
            make.width.equalTo(scrollView).offset(-64)
        }
    }

    /// Adds given label and control to the stack view with proper insets
    private func add(label: UILabel, control: UIView, topInset: Double = 13, bottomInset: Double = 13) {
        // wrapper to add leading/trailing insets
        let wrapper = UIView()
        let labelAndControl = UIStackView()
        labelAndControl.axis = .horizontal
        labelAndControl.alignment = .center
        labelAndControl.addArrangedSubview(label)
        labelAndControl.addArrangedSubview(control)
        wrapper.addSubview(labelAndControl)
        stackView.addArrangedSubview(wrapper)
        labelAndControl.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(topInset)
            make.bottom.equalToSuperview().inset(bottomInset)
            make.leading.trailing.equalToSuperview().inset(16)
            make.width.equalTo(scrollView).offset(-64)
        }
    }

    /// add some empty space
    private func addSpace(height: Double) {
        let space = UIView()
        space.backgroundColor = stackView.backgroundColor
        stackView.addArrangedSubview(space)
        space.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(height)
        }
    }

    /// leftInset insets the line from the left (makes it shorter)
    private func addSeparator(leftInset: Double = 0.0) {
        let separator = UIView()
        separator.backgroundColor = .dynamic(.Neutral_07)
        stackView.addArrangedSubview(separator)
        separator.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(leftInset)
            make.height.equalTo(1)
        }
    }

    private func addAssigneeFilterTypeView() {
        let wrapper = UIView()
        wrapper.addSubview(assigneeFilterTypeToggle)
        stackView.addArrangedSubview(wrapper)
        assigneeFilterTypeToggle.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(32)
        }
        stackView.setCustomSpacing(9, after: wrapper)
    }

    private func addDateCreatedSelectorView() {
        dateCreatedSelectorView.backgroundColor = stackView.backgroundColor
        stackView.addArrangedSubview(dateCreatedSelectorView)
        dateCreatedSelectorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }
    }

    private func addDateUpdatedSelectorView() {
        dateUpdatedSelectorView.backgroundColor = stackView.backgroundColor
        stackView.addArrangedSubview(dateUpdatedSelectorView)
        dateUpdatedSelectorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }
    }

    private func addUsersView() {
        usersView.backgroundColor = stackView.backgroundColor
        stackView.addArrangedSubview(usersView)
        usersView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }
        usersView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(usersTapped)))

        addLeftRightGradients(to: usersView)
    }

    private func addCanvasesView() {
        canvasesView.backgroundColor = stackView.backgroundColor
        stackView.addArrangedSubview(canvasesView)
        canvasesView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }
        canvasesView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(canvasesTapped)))

        addLeftRightGradients(to: canvasesView)
    }

    private func addTagsView() {
        tagsView.backgroundColor = stackView.backgroundColor
        stackView.addArrangedSubview(tagsView)
        tagsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }
        tagsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tagsTapped)))

        addLeftRightGradients(to: tagsView)
    }

    private func addLeftRightGradients(to superView: UIView) {
        let leftGradientView = createLeftGradient()
        let rightGradientView = createRightGradient()
        superView.addSubview(leftGradientView)
        superView.addSubview(rightGradientView)
        leftGradientView.snp.makeConstraints { make in
            make.width.equalTo(24)
            make.top.bottom.left.equalToSuperview()
        }
        rightGradientView.snp.makeConstraints { make in
            make.width.equalTo(24)
            make.top.bottom.right.equalToSuperview()
        }
        gradientViews.append(leftGradientView)
        gradientViews.append(rightGradientView)
    }

    private func createLeftGradient() -> GradientView {
        let leftGradientView = GradientView()
        leftGradientView.backgroundColor = .clear
        // left to right gradient
        leftGradientView.gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        leftGradientView.gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        return leftGradientView
    }

    private func createRightGradient() -> GradientView {
        let rightGradientView = GradientView()
        rightGradientView.backgroundColor = .clear
        // right to left gradient
        rightGradientView.gradientLayer.startPoint = CGPoint(x: 1, y: 0.5)
        rightGradientView.gradientLayer.endPoint = CGPoint(x: 0, y: 0.5)
        return rightGradientView
    }

    private func createLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .dynamic(.Neutral_04)
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
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

    override func updateColors() {
        super.updateColors()
        stackView.layer.borderColor = chooseColor(.Neutral_07).cgColor
        let gradientColor = chooseColor(.Neutral_09)
        gradientViews.forEach {
            $0.gradientLayer.colors = [
                gradientColor.cgColor,
                gradientColor.withAlphaComponent(0).cgColor,
            ]
        }
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        let baseHeight = super.height(forContainer: cardContainerView, cardPosition: cardPosition)

        if cardPosition == .max {
            view.layoutIfNeeded()
            return baseHeight + scrollView.contentSize.height + 12.0
        }
        return baseHeight
    }

    override func drivingScrollView() -> UIScrollView? {
        scrollView
    }
}

// MARK: - assignee

extension TaskListFiltersCardViewController: UsersViewModelDelegate {
    /// Called when "Filter by Assignee" type is changed
    private func onAssigneeFilterTypeChanged() {
        usersViewModel.set(selectedUsersWithIds: filters.assigneeFilter ?? [])
        if filters.assigneeFilterType == .select {
            showUsersPicker()
        }
        usersView.setVisible(filters.assigneeFilterType == .select)
        if let cardDragging = cardDragging {
            cardDragging.setCardHeight(cardDragging.cardHeight(forPosition: cardDragging.position), animated: true)
        }
    }

    /// Invoked when selected users tapped
    @objc private func usersTapped() {
        showUsersPicker()
    }

    /// Show the picker that operates on usersViewModel
    func showUsersPicker() {
        guard let presentingVC = presentingVC else { return }
        let userPickerCardVC = UserPickerCardViewController(title: "Assignee's", viewModel: usersViewModel)
        userPickerCardVC.showNoUserOption = true
        userPickerCardVC.installAndShowCard(in: presentingVC)
    }

    /// Updates assignee filters when the usersViewModel is updated
    func usersViewModel(
        _ viewModel: UsersViewModel,
        user _: UserViewModel,
        selected _: Bool,
        indexInSelectedUsers _: Int
    ) {
        filters.setAssigneeFilter(viewModel.selectedUsers.map(\.id))
    }
}

// MARK: - canvas

extension TaskListFiltersCardViewController: CanvasesViewModelDelegate {
    /// Called when "Filter by Canvas" switch is toggled
    private func onFilterByCanvasSwitchAction() {
        if filterByCanvasSwitch.isOn {
            filters.canvasFilter = []
            canvasesView.setVisible(true)
            showCanvasPicker()
        } else {
            canvasesViewModel.clearSelection()
            filters.canvasFilter = nil
            canvasesView.setVisible(false)
        }
        if let cardDragging = cardDragging {
            cardDragging.setCardHeight(cardDragging.cardHeight(forPosition: cardDragging.position), animated: true)
        }
    }

    /// Invoked when selected canvases tapped
    @objc private func canvasesTapped() {
        showCanvasPicker()
    }

    /// Show the picker that operates on canvasesViewModel
    func showCanvasPicker() {
        guard let presentingVC = presentingVC else { return }
        let pickerCardVC = CanvasPickerCardViewController(title: "Canvas", viewModel: canvasesViewModel)
        pickerCardVC.installAndShowCard(in: presentingVC)
    }

    /// Updates canvas filters when the viewModel is updated
    func canvasesViewModel(
        _ viewModel: CanvasesViewModel,
        canvas _: CanvasViewModel,
        selected _: Bool,
        indexInSelectedCanvases _: Int
    ) {
        filters.canvasFilter = viewModel.selectedCanvases.map(\.id)
    }
}

// MARK: - tags

extension TaskListFiltersCardViewController: TagsViewModelDelegate {
    /// Called when "Filter by Tags" switch is toggled
    private func onFilterByTagsSwitchAction() {
        if filterByTagsSwitch.isOn {
            filters.tagsFilter = []
            tagsView.setVisible(true)
            showTagsSelector()
        } else {
            tagsViewModel.clearSelection()
            filters.tagsFilter = nil
            tagsView.setVisible(false)
        }
        if let cardDragging = cardDragging {
            cardDragging.setCardHeight(cardDragging.cardHeight(forPosition: cardDragging.position), animated: true)
        }
    }

    /// Invoked when selected tags are tapped
    @objc private func tagsTapped() {
        showTagsSelector()
    }

    /// Show Tags selection card operating on the tagsViewModel used by this card (so all changes are propagated to this view automatically)
    private func showTagsSelector() {
        guard let presentingVC = presentingVC else { return }
        let editTagsVC = SearchAndSelectTagsViewController(tagsViewModel: tagsViewModel)
        editTagsVC.showCreateTag = false
        editTagsVC.showUntaggedOption = true
        editTagsVC.showTagCount = false
        editTagsVC.installAndShowCard(in: presentingVC, inView: view.superview)
    }

    /// Updates tags filters when the tagsViewModel is updated
    func tagsViewModel(_ viewModel: TagsViewModel, tag _: TagViewModel, selected _: Bool, indexInSelectedTags _: Int) {
        filters.tagsFilter = viewModel.selectedTags.map(\.id)
    }
}
