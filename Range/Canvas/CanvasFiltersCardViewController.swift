import Combine
import Foundation
import RealmSwift
import UIKit

/// Card view controller presenting filters for canvas
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class CanvasFiltersCardViewController: SheetCardViewController {
    unowned let model: ProjectModel
    private let canvasFilters: CanvasFilters
    private let statuses: [Status]
    private let usersViewModel: UsersViewModel
    private let tagsViewModel: TagsViewModel

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private let showPhotoPinsSwitch = UISwitch()
    private let showTaskPinsSwitch = UISwitch()
    private var statusLabels = [Status: UILabel]()
    private var statusSwitches = [Status: UISwitch]()
    private let filterByAssigneeSwitch = UISwitch()
    private let usersView: SelectedUsersView
    private let filterByTagsSwitch = UISwitch()
    private let tagsView: SelectedTagsView
    private let showOnlyCreatedByUserSwitch = UISwitch()
    private let showArchivedPinsSwitch = UISwitch()

    private var gradientViews = [GradientView]()

    /// Initializer
    ///
    /// - Parameters:
    ///     - canvasFilters:                         CanvasFilters
    init(model: ProjectModel, canvasFilters: CanvasFilters) {
        self.model = model
        self.canvasFilters = canvasFilters
        statuses = (model.mainRealm.objects(Status.self).sorted(by: Status.uiSortingOrder))
        let usersViewModel = UsersViewModel(model: model, multiselect: true)
        // TODO: 993 preselect users from filters
        usersView = SelectedUsersView(viewModel: usersViewModel, showEditUserCell: true)
        self.usersViewModel = usersViewModel
        let tagsViewModel = TagsViewModel(model: model)
        // preselect tags from the filter
        canvasFilters.tagsFilter?.forEach { tagsViewModel.set(tagWithId: $0, selected: true) }
        tagsView = SelectedTagsView(viewModel: tagsViewModel, showEditTagCell: true)
        self.tagsViewModel = tagsViewModel
        super.init(
            icon: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            title: String(localized: "Canvas Filters")
        )
        usersViewModel.addDelegate(self)
        tagsViewModel.addDelegate(self)
    }

    var _Subscriber: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

        // add a switch per status
        for status in statuses {
            let statusSwitch = UISwitch()
            statusSwitch.setOn(canvasFilters.show(status), animated: false)
            statusSwitch.addAction(.init(handler: { [weak self] action in
                guard let sender = action.sender as? UISwitch else { return }
                self?.canvasFilters.set(status, shown: sender.isOn)
            }), for: .valueChanged)
            statusSwitches[status] = statusSwitch
            statusLabels[status] = createLabel(text: status.name)
        }

        setupViews()

        showPhotoPinsSwitch.setOn(canvasFilters.showPhotoPins, animated: false)
        showPhotoPinsSwitch.addAction(.init(handler: { [weak self] _ in
            self?.canvasFilters.showPhotoPins.toggle()
        }), for: .valueChanged)

        showTaskPinsSwitch.setOn(canvasFilters.showTaskPins, animated: false)
        showTaskPinsSwitch.addAction(.init(handler: { [weak self] _ in
            self?.canvasFilters.showTaskPins.toggle()
            self?.updateTaskPinsEnabled()
        }), for: .valueChanged)

        // TODO: 993
//        filterByAssigneeSwitch.setOn(!= nil, animated: false)
        filterByAssigneeSwitch.addAction(.init(handler: { [weak self] _ in
            self?.onFilterByAssigneeSwitchAction()
        }), for: .valueChanged)

        filterByTagsSwitch.setOn(canvasFilters.tagsFilter != nil, animated: false)
        filterByTagsSwitch.addAction(.init(handler: { [weak self] _ in
            self?.onFilterByTagsSwitchAction()
        }), for: .valueChanged)

        showOnlyCreatedByUserSwitch.setOn(canvasFilters.showOnlyCreatedByUser, animated: false)
        showOnlyCreatedByUserSwitch.addAction(.init(handler: { [weak self] _ in
            self?.canvasFilters.showOnlyCreatedByUser.toggle()
        }), for: .valueChanged)

        showArchivedPinsSwitch.setOn(canvasFilters.showArchivedPins, animated: false)
        showArchivedPinsSwitch.addAction(.init(handler: { [weak self] _ in
            self?.canvasFilters.showArchivedPins.toggle()
        }), for: .valueChanged)

        // TODO: 993
        usersView.setVisible(false, animated: false)
        tagsView.setVisible(canvasFilters.tagsFilter != nil, animated: false)
        updateTaskPinsEnabled()
    }

    /// Update the enabled state of task filters (statuses and assignee)
    private func updateTaskPinsEnabled() {
        let enabled = canvasFilters.showTaskPins
        for status in statuses {
            statusLabels[status]?.isEnabled = enabled
            statusSwitches[status]?.isEnabled = enabled
        }
    }

    private func setupViews() {
        // Scroll view setup
        scrollView.alwaysBounceVertical = true
        containerView.addSubview(scrollView)
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
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }

        // ----- Photo pins ------------------------------------------------------------------------
        add(label: createLabel(text: String(localized: "Show Photo Pins")), control: showPhotoPinsSwitch)
        addSeparator()

        // ----- Task pins (+ statuses) ------------------------------------------------------------
        add(label: createLabel(text: String(localized: "Show Task Pins")), control: showTaskPinsSwitch)
        addSeparator(leftInset: 16)
        for (index, status) in statuses.enumerated() {
            if let statusLabel = statusLabels[status], let statusSwitch = statusSwitches[status] {
                add(label: statusLabel, control: statusSwitch, topInset: index == 0 ? 13 : 5,
                    bottomInset: index == (statuses.count - 1) ? 13 : 5)
            }
        }
        addSeparator()

        // ----- Assignee --------------------------------------------------------------------------
        add(label: createLabel(text: String(localized: "Filter by Assignee")), control: filterByAssigneeSwitch,
            bottomInset: 4) // the rest = 9 is added below users view
        addUsersView()
        addSpace(height: 9)
        addSeparator()

        // ----- Tags ------------------------------------------------------------------------------
        add(label: createLabel(text: String(localized: "Filter by Tags")), control: filterByTagsSwitch,
            bottomInset: 4) // the rest = 9 is added below tags view
        addTagsView()
        addSpace(height: 9)
        addSeparator()

        // ----- Pins I've created -----------------------------------------------------------------
        add(label: createLabel(text: String(localized: "Only Show Pins I've Created")),
            control: showOnlyCreatedByUserSwitch)
        addSeparator()

        // ----- Archived pins ---------------------------------------------------------------------
        add(label: createLabel(text: String(localized: "Show Archived Pins")), control: showArchivedPinsSwitch)
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

extension CanvasFiltersCardViewController: UsersViewModelDelegate {
    /// Called when "Filter by Assignee" switch is toggled
    private func onFilterByAssigneeSwitchAction() {
        if filterByAssigneeSwitch.isOn {
            // TODO: 993
//            canvasFilters.tagsFilter = []
            usersView.setVisible(true)
            showUsersPicker()
        } else {
            usersViewModel.clearSelection()
            // TODO: 993
//            canvasFilters.tagsFilter = nil
            usersView.setVisible(false)
        }
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
        UserPickerCardViewController(title: "Assignee's", viewModel: usersViewModel, onClose: nil)
            .installAndShowCard(in: presentingVC)
    }
}

// MARK: - tags

extension CanvasFiltersCardViewController: TagsViewModelDelegate {
    /// Called when "Filter by Tags" switch is toggled
    private func onFilterByTagsSwitchAction() {
        if filterByTagsSwitch.isOn {
            canvasFilters.tagsFilter = []
            tagsView.setVisible(true)
            showTagsSelector()
        } else {
            tagsViewModel.clearSelection()
            canvasFilters.tagsFilter = nil
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
        editTagsVC.onClose = {
            editTagsVC.hideCard(animated: true) {
                presentingVC.removeCard(cardViewController: editTagsVC)
            }
        }
        presentingVC.installCard(
            cardViewController: editTagsVC,
            inView: view.superview,
            cardConfig: CardConfiguration(initialCardPosition: .max, interactive: false, showOverlay: true)
        )
        editTagsVC.showCard(animated: true)
    }

    /// Updates tags filters when the tagsViewModel is updated
    func tagsViewModel(_ viewModel: TagsViewModel, tag _: TagViewModel, selected _: Bool, indexInSelectedTags _: Int) {
        canvasFilters.tagsFilter = viewModel.selectedTags.map(\.id)
    }
}
