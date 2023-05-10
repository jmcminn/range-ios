import Foundation

import UIKit

/// Card view controller presenting a date picker
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class DatePickerCardViewController: SheetCardViewController {
    private let datePickerBackground = UIView()
    private let datePicker = UIDatePicker()
    private var leftButton: UIButton! // either "cancel" or "remove date" button
    private var doneButton: UIButton!
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
    init(
        title: String?,
        timeZone: TimeZone,
        minimumDate: Date? = nil,
        initialSelectedDate: Date? = nil,
        onDatePicked: ((Date?) -> Void)? = nil
    ) {
        self.timeZone = timeZone
        super.init(icon: UIImage(systemName: "calendar"), title: title)
        selectedDate = initialSelectedDate
        self.onDatePicked = onDatePicked
        datePicker.minimumDate = minimumDate
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupDatePicker()
        containerView.addSubview(datePickerBackground)
        datePickerBackground.addSubview(datePicker)
        datePickerBackground.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        datePicker.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(10)
        }

        setupButtons()
        containerView.addSubview(leftButton)
        containerView.addSubview(doneButton)
        leftButton.snp.makeConstraints { make in
            make.leading.equalTo(16)
            make.top.equalTo(doneButton)
            make.trailing.equalTo(doneButton.snp.leading).offset(-16)
            make.width.equalTo(doneButton.snp.width)
        }
        doneButton.snp.makeConstraints { make in
            make.trailing.equalTo(-16)
            make.top.equalTo(datePickerBackground.snp.bottom).offset(16)
            make.height.equalTo(leftButton)
        }

        handleDateSelection()
    }

    override func updateColors() {
        super.updateColors()

        datePickerBackground.layer.borderColor = UIColor.dynamic(.Neutral_07).cgColor
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        let baseHeight = super.height(forContainer: cardContainerView, cardPosition: cardPosition)
        if cardPosition == .max {
            view.layoutIfNeeded()
            return max(leftButton.frame.maxY, doneButton.frame.maxY) + 16
        }
        return baseHeight
    }

    @objc func handleDateSelection() {
        selectedDate = datePicker.date
    }
}

// MARK: Views

extension DatePickerCardViewController {
    private func setupDatePicker() {
        datePickerBackground.layer.cornerRadius = 13
        datePickerBackground.layer.borderWidth = 1
        datePickerBackground.backgroundColor = .dynamic(.Neutral_09)

        datePicker.datePickerMode = .date
        if let selectedDate = selectedDate {
            datePicker.date = selectedDate
        }
        datePicker.timeZone = timeZone
        datePicker.preferredDatePickerStyle = .inline
        datePicker.tintColor = .Pink_03
        datePicker.backgroundColor = .dynamic(.Neutral_09)
        datePicker.clipsToBounds = true
        datePicker.addTarget(self, action: #selector(handleDateSelection), for: .valueChanged)
    }

    private func setupButtons() {
        if selectedDate == nil {
            // no initial date, just cancel
            leftButton = UIButton(
                configuration: UIButton.Configuration.grayButton(),
                primaryAction: UIAction(title: String(localized: "Cancel")) { [weak self] _ in
                    self?.dismissCard()
                }
            )
        } else {
            // remove current date button
            leftButton = UIButton(
                configuration: UIButton.Configuration.redButton(),
                primaryAction: UIAction(
                    title: String(localized: "Remove Date"),
                    image: UIImage(systemName: "trash")
                ) { [weak self] _ in
                    self?.selectedDate = nil
                    self?.dismissCard()
                    self?.onDatePicked?(self?.selectedDate)
                }
            )
        }
        doneButton = UIButton(
            configuration: UIButton.Configuration.blueButton(imagePlacement: .leading),
            primaryAction: UIAction(title: "Done") { [weak self] _ in
                self?.dismissCard()
                self?.onDatePicked?(self?.selectedDate)
            }
        )
    }
}
