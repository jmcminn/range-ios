import Combine
import Foundation
import UIKit

/// Card view controller presenting filters for canvas
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class CanvasFiltersCardViewController: SheetCardViewController {
    unowned let model: ProjectModel
    private let canvasFilters: CanvasFilters
    private let statuses: [Status]

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private let showPhotoPinsSwitch = UISwitch()
    private let showTaskPinsSwitch = UISwitch()
    private var statusLabels = [Status: UILabel]()
    private var statusSwitches = [Status: UISwitch]()

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

        showOnlyCreatedByUserSwitch.setOn(canvasFilters.showOnlyCreatedByUser, animated: false)
        showOnlyCreatedByUserSwitch.addAction(.init(handler: { [weak self] _ in
            self?.canvasFilters.showOnlyCreatedByUser.toggle()
        }), for: .valueChanged)

        showArchivedPinsSwitch.setOn(canvasFilters.showArchivedPins, animated: false)
        showArchivedPinsSwitch.addAction(.init(handler: { [weak self] _ in
            self?.canvasFilters.showArchivedPins.toggle()
        }), for: .valueChanged)

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
        scrollView.alwaysBounceVertical = true

        containerView.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.bottom.equalToSuperview().inset(12)
        }

        stackView.axis = .vertical
        stackView.layer.cornerRadius = 13
        stackView.layer.borderWidth = 1
        stackView.backgroundColor = .dynamic(.Neutral_09)

        scrollView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }

        add(label: createLabel(text: String(localized: "Show Photo Pins")), control: showPhotoPinsSwitch)
        addSeparator()
        add(label: createLabel(text: String(localized: "Show Task Pins")), control: showTaskPinsSwitch)
        addSeparator(leftInset: 16)
        for (index, status) in statuses.enumerated() {
            if let statusLabel = statusLabels[status], let statusSwitch = statusSwitches[status] {
                add(label: statusLabel, control: statusSwitch, topInset: index == 0 ? 13 : 5,
                    bottomInset: index == (statuses.count - 1) ? 13 : 5)
            }
        }
        addSeparator()
        add(
            label: createLabel(text: String(localized: "Only Show Pins I've Created")),
            control: showOnlyCreatedByUserSwitch
        )
        addSeparator()
        add(label: createLabel(text: String(localized: "Show Archived Pins")), control: showArchivedPinsSwitch)
    }

    /// Adds given label and control to the stack view with proper insets
    private func add(label: UILabel, control: UIView, topInset: Double = 13, bottomInset: Double = 13) {
        // wrapper to add leading/trailing insets
        let wrapper = UIView()
        let labelAndControl = UIStackView()
        labelAndControl.axis = .horizontal
        labelAndControl.spacing = 16
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

    private func addSeparator(leftInset: Double = 0.0) {
        let separator = UIView()
        separator.backgroundColor = .dynamic(.Neutral_07)
        stackView.addArrangedSubview(separator)
        separator.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(leftInset)
            make.height.equalTo(1)
        }
    }

    private func createLabel(text: String) -> UILabel {
        let label = UILabel()
        label.textColor = .dynamic(.Neutral_04)
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.text = text
        return label
    }

    override func updateColors() {
        super.updateColors()
        stackView.layer.borderColor = chooseColor(.Neutral_07).cgColor
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
