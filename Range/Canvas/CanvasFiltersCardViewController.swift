import Foundation
import UIKit

/// Card view controller presenting filters for canvas
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class CanvasFiltersCardViewController: SheetCardViewController {
    private let userSettings: UserSettings

    private let boxView = UIView()
    private let showArchivedPinsLabel = UILabel()
    private let showArchivedPinsSwitch = UISwitch()

    /// Initializer
    ///
    /// - Parameters:
    ///     - userSettings:                         UserSettings
    init(userSettings: UserSettings) {
        self.userSettings = userSettings
        super.init(
            icon: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            title: String(localized: "Canvas Filters")
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        containerView.addSubview(boxView)
        boxView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(sheetHeaderView.snp.bottom)
        }

        showArchivedPinsSwitch.setOn(userSettings.showArchivedCollaborations, animated: false)
        showArchivedPinsSwitch.addTarget(self, action: #selector(toggleShowArchivedPins), for: .valueChanged)
    }

    @objc
    private func toggleShowArchivedPins() {
        userSettings.showArchivedCollaborations = !userSettings.showArchivedCollaborations
    }

    private func setupViews() {
        boxView.layer.cornerRadius = 13
        boxView.layer.borderWidth = 1
        boxView.backgroundColor = .dynamic(.Neutral_09)

        showArchivedPinsLabel.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        showArchivedPinsLabel.font = .preferredFont(forTextStyle: .body)
        showArchivedPinsLabel.adjustsFontForContentSizeCategory = true
        showArchivedPinsLabel.text = String(localized: "Show Archived Pins")

        boxView.addSubview(showArchivedPinsLabel)
        showArchivedPinsLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.bottom.equalToSuperview().inset(18)
        }

        boxView.addSubview(showArchivedPinsSwitch)
        showArchivedPinsSwitch.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(16)
        }
    }

    override func updateColors() {
        super.updateColors()
        boxView.layer.borderColor = chooseColor(light: .Neutral_04, dark: .Neutral_07).cgColor
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
