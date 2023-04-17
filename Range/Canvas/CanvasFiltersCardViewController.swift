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
    private let tagsViewModel: TagsViewModel

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private let showPhotoPinsSwitch = UISwitch()
    private let showTaskPinsSwitch = UISwitch()
    private var statusLabels = [Status: UILabel]()
    private var statusSwitches = [Status: UISwitch]()
    private let filterByTagsSwitch = UISwitch()
    private let tagsView: SelectedTagsView
    private let leftTagsViewGradient = GradientView()
    private let rightTagsViewGradient = GradientView()
    private let showOnlyCreatedByUserSwitch = UISwitch()
    private let showArchivedPinsSwitch = UISwitch()

    /// Initializer
    ///
    /// - Parameters:
    ///     - canvasFilters:                         CanvasFilters
    init(model: ProjectModel, canvasFilters: CanvasFilters) {
        self.model = model
        self.canvasFilters = canvasFilters
        statuses = (model.mainRealm.objects(Status.self).sorted(by: Status.uiSortingOrder))
        let tagsViewModel = TagsViewModel(model: model)
        // preselect tags from the filter
        canvasFilters.tagsFilter?.forEach { tagsViewModel.set(tagWithId: $0, selected: true) }
        tagsView = SelectedTagsView(viewModel: tagsViewModel)
        self.tagsViewModel = tagsViewModel
        super.init(
            icon: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            title: String(localized: "Canvas Filters")
        )
    }

    var _Subscriber: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

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

        filterByTagsSwitch.setOn(canvasFilters.tagsFilter != nil, animated: false)
        filterByTagsSwitch.addAction(.init(handler: { [weak self] action in
            guard let self = self, let sender = action.sender as? UISwitch else { return }
            if sender.isOn {
                self.canvasFilters.tagsFilter = []
                self.tagsView.setVisible(true)
            } else {
                self.tagsViewModel.clearSelection()
                self.canvasFilters.tagsFilter = nil
                self.tagsView.setVisible(false)
            }
            if let cardDragging = self.cardDragging {
                cardDragging.setCardHeight(cardDragging.cardHeight(forPosition: cardDragging.position), animated: true)
            }
        }), for: .valueChanged)

        showOnlyCreatedByUserSwitch.setOn(canvasFilters.showOnlyCreatedByUser, animated: false)
        showOnlyCreatedByUserSwitch.addAction(.init(handler: { [weak self] _ in
            self?.canvasFilters.showOnlyCreatedByUser.toggle()
        }), for: .valueChanged)

        showArchivedPinsSwitch.setOn(canvasFilters.showArchivedPins, animated: false)
        showArchivedPinsSwitch.addAction(.init(handler: { [weak self] _ in
            self?.canvasFilters.showArchivedPins.toggle()
        }), for: .valueChanged)

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

    private func addTagsView() {
        tagsView.showEditTagCell = true
        tagsView.backgroundColor = stackView.backgroundColor
        stackView.addArrangedSubview(tagsView)
        tagsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }
        tagsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tagsTapped)))

        leftTagsViewGradient.backgroundColor = .clear
        // left to right gradient
        leftTagsViewGradient.gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        leftTagsViewGradient.gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)

        rightTagsViewGradient.backgroundColor = .clear
        // right to left gradient
        rightTagsViewGradient.gradientLayer.startPoint = CGPoint(x: 1, y: 0.5)
        rightTagsViewGradient.gradientLayer.endPoint = CGPoint(x: 0, y: 0.5)

        tagsView.addSubview(leftTagsViewGradient)
        tagsView.addSubview(rightTagsViewGradient)
        leftTagsViewGradient.snp.makeConstraints { make in
            make.width.equalTo(24)
            make.top.bottom.left.equalToSuperview()
        }
        rightTagsViewGradient.snp.makeConstraints { make in
            make.width.equalTo(24)
            make.top.bottom.right.equalToSuperview()
        }
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
        leftTagsViewGradient.gradientLayer.colors = [
            gradientColor.cgColor,
            gradientColor.withAlphaComponent(0).cgColor,
        ]
        rightTagsViewGradient.gradientLayer.colors = [
            gradientColor.cgColor,
            gradientColor.withAlphaComponent(0).cgColor,
        ]
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

extension CanvasFiltersCardViewController {
    @objc private func tagsTapped() {
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
}
