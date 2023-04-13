import Combine
import Foundation
import UIKit

/// Card view controller presenting filters for canvas
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class CanvasFiltersCardViewController: SheetCardViewController {
    private let canvasFilters: CanvasFilters

    private let boxView = UIView()

    private let showPhotoPinsSwitch = UISwitch()
    private let showTaskPinsSwitch = UISwitch()
    private let showArchivedPinsSwitch = UISwitch()

    /// Initializer
    ///
    /// - Parameters:
    ///     - canvasFilters:                         CanvasFilters
    init(canvasFilters: CanvasFilters) {
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
        containerView.addSubview(boxView)
        boxView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(sheetHeaderView.snp.bottom)
        }

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
        boxView.layer.cornerRadius = 13
        boxView.layer.borderWidth = 1
        boxView.backgroundColor = .dynamic(.Neutral_09)

        let showPhotoPinsLabel = createLabel(text: String(localized: "Show Photo Pins"))
        boxView.addSubview(showPhotoPinsLabel)
        showPhotoPinsLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.equalToSuperview().inset(18)
        }

        boxView.addSubview(showPhotoPinsSwitch)
        showPhotoPinsSwitch.snp.makeConstraints { make in
            make.centerY.equalTo(showPhotoPinsLabel)
            make.trailing.equalToSuperview().inset(16)
        }

        let showTaskPinsLabel = createLabel(text: String(localized: "Show Task Pins"))
        boxView.addSubview(showTaskPinsLabel)
        showTaskPinsLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.equalTo(showPhotoPinsLabel.snp.bottom).offset(30)
        }

        boxView.addSubview(showTaskPinsSwitch)
        showTaskPinsSwitch.snp.makeConstraints { make in
            make.centerY.equalTo(showTaskPinsLabel)
            make.trailing.equalToSuperview().inset(16)
        }

        let showArchivedPinsLabel = createLabel(text: String(localized: "Show Archived Pins"))
        boxView.addSubview(showArchivedPinsLabel)
        showArchivedPinsLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.equalTo(showTaskPinsLabel.snp.bottom).offset(30)
            make.bottom.equalToSuperview().inset(18)
        }

        boxView.addSubview(showArchivedPinsSwitch)
        showArchivedPinsSwitch.snp.makeConstraints { make in
            make.centerY.equalTo(showArchivedPinsLabel)
            make.trailing.equalToSuperview().inset(16)
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
        boxView.layer.borderColor = chooseColor(.Neutral_07).cgColor
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        let baseHeight = super.height(forContainer: cardContainerView, cardPosition: cardPosition)

        if cardPosition == .max {
            view.layoutIfNeeded()
            return baseHeight + boxView.frame.height + 12.0
        }
        return baseHeight
    }
}
