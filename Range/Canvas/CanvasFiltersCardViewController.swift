import Combine
import Foundation
import UIKit

/// Card view controller presenting filters for canvas
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class CanvasFiltersCardViewController: SheetCardViewController {
    unowned let model: ProjectModel
    private let canvasFilters: CanvasFilters

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private let showPhotoPinsSwitch = UISwitch()
    private let showTaskPinsSwitch = UISwitch()
    private let showArchivedPinsSwitch = UISwitch()

    /// Initializer
    ///
    /// - Parameters:
    ///     - canvasFilters:                         CanvasFilters
    init(model: ProjectModel, canvasFilters: CanvasFilters) {
        self.model = model
        self.canvasFilters = canvasFilters
        super.init(
            icon: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            title: String(localized: "Canvas Filters")
        )
    }

    var _Subscriber: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()

        showPhotoPinsSwitch.setOn(canvasFilters.showPhotoPins, animated: false)
        showPhotoPinsSwitch.addAction(.init(handler: { [weak self] _ in
            self?.canvasFilters.showPhotoPins.toggle()
        }), for: .valueChanged)

        showTaskPinsSwitch.setOn(canvasFilters.showTaskPins, animated: false)
        showTaskPinsSwitch.addAction(.init(handler: { [weak self] _ in
            self?.canvasFilters.showTaskPins.toggle()
        }), for: .valueChanged)

        showArchivedPinsSwitch.setOn(canvasFilters.showArchivedPins, animated: false)
        showArchivedPinsSwitch.addAction(.init(handler: { [weak self] _ in
            self?.canvasFilters.showArchivedPins.toggle()
        }), for: .valueChanged)
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
//        let statuses = [Status](model.mainRealm.objects(Status.self).sorted(by: Status.uiSortingOrder))
//        for status in statuses {
//            // TODO: 993
//        }
        addSeparator()
        add(label: createLabel(text: String(localized: "Show Archived Pins")), control: showArchivedPinsSwitch)
    }

    /// Adds given label and control to the stack view with proper insets
    private func add(label: UILabel, control: UIView) {
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
            make.top.bottom.equalToSuperview().inset(13)
            make.leading.trailing.equalToSuperview().inset(16)
            make.width.equalTo(scrollView).offset(-64)
        }
    }

    private func addSeparator() {
        let separator = UIView()
        separator.backgroundColor = .dynamic(.Neutral_07)
        stackView.addArrangedSubview(separator)
        separator.snp.makeConstraints { make in
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
