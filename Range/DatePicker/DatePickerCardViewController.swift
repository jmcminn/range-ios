import Foundation

import UIKit

/// Card view controller presenting a date picker
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class DatePickerCardViewController: SheetCardViewController {
    private let datePicker = UIDatePicker()
    private let selectedDateLabel = LabelWithTextInsets()
    private var clearSelectionButton: UIButton!
    let timeZone: TimeZone

    var selectedDate: Date?
    /// called when user selects a date. The date has the same time as the initial selected date (or "now" if the initial date was
    /// not provided)
    var onDatePicked: ((Date?) -> Void)?

    /// Initializer
    ///
    /// - Parameters:
    ///     - title:                         title of the card
    ///     - initialSelectedDate: the date to select initially, or today if `nil`
    init(title: String?, timeZone: TimeZone, initialSelectedDate: Date? = nil, onDatePicked: ((Date?) -> Void)? = nil) {
        self.timeZone = timeZone
        super.init(icon: UIImage(systemName: "calendar"), title: title)
        selectedDate = initialSelectedDate
        self.onDatePicked = onDatePicked
        onDismiss = { [weak self] in
            self?.onDatePicked?(self?.selectedDate)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupDatePicker()
        containerView.addSubview(datePicker)
        datePicker.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            if let subtitleLabel = subtitleLabel {
                make.top.equalTo(subtitleLabel.snp.bottom).offset(16)
            } else {
                make.top.equalTo(closeButton.snp.bottom).offset(16)
            }
        }

        setupSelectedDateLabel()
        containerView.addSubview(selectedDateLabel)
        selectedDateLabel.snp.makeConstraints { make in
            make.top.equalTo(datePicker.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        setupClearSelectionButton()
        containerView.addSubview(clearSelectionButton)
        clearSelectionButton.snp.makeConstraints { make in
            make.centerY.trailing.equalTo(selectedDateLabel)
            make.width.height.equalTo(40)
        }

        handleDateSelection()
    }

    override func updateColors() {
        super.updateColors()

        datePicker.layer.borderColor = UIColor.dynamicColor(light: .Neutral_04, dark: .Neutral_07).cgColor
        selectedDateLabel.layer.borderColor = UIColor.dynamicColor(light: .Neutral_04, dark: .Neutral_07).cgColor
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        let baseHeight = super.height(forContainer: cardContainerView, cardPosition: cardPosition)
        if cardPosition == .max {
            view.layoutIfNeeded()
            return selectedDateLabel.frame.maxY + 16
        }
        return baseHeight
    }

    @objc func handleDateSelection() {
        selectedDateLabel.text = Date.dueDateFormat2(datePicker.date, timeZone: timeZone)
        selectedDate = datePicker.date
    }
}

// MARK: Views

extension DatePickerCardViewController {
    private func setupDatePicker() {
        datePicker.datePickerMode = .date
        if let selectedDate = selectedDate {
            datePicker.date = selectedDate
        }
        datePicker.timeZone = timeZone
        datePicker.preferredDatePickerStyle = .inline
        datePicker.tintColor = .Pink_03
        datePicker.layer.cornerRadius = 13
        datePicker.layer.borderWidth = 1
        datePicker.backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
        datePicker.clipsToBounds = true
        datePicker.addTarget(self, action: #selector(handleDateSelection), for: .valueChanged)
    }

    private func setupSelectedDateLabel() {
        selectedDateLabel.textInsets = UIEdgeInsets(top: 13, left: 0, bottom: 13, right: 0)
        selectedDateLabel.layer.cornerRadius = 13
        selectedDateLabel.layer.borderWidth = 1
        selectedDateLabel.backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
        selectedDateLabel.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        selectedDateLabel.font = UIFont._preferredFont(forTextStyle: .body, symbolicTraits: .traitBold)
        selectedDateLabel.clipsToBounds = true
        selectedDateLabel.textAlignment = .center
    }

    private func setupClearSelectionButton() {
        let imageConfig = UIImage.SymbolConfiguration(textStyle: .footnote)
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_05)
        config.preferredSymbolConfigurationForImage = imageConfig

        clearSelectionButton = UIButton(
            configuration: config,
            primaryAction: UIAction(image: UIImage(systemName: "xmark.circle.fill")) { [weak self] _ in
                self?.selectedDate = nil
                self?.dismissCard()
            }
        )
    }
}
