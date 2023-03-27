import Foundation
import UIKit

// TODO: this is almost a copy&paste of AssigneeButton, maybe if there's another similar button
// it can be refactored to some common button...
/// Displays a due date
class DueDateButton: UIButton {
    private let timeZone: TimeZone

    /// The due date
    private(set) var dueDate: Date?
    private(set) var markOverdue: Bool = false

    /// - Parameters:
    ///     - timezone: the timezone in which to display the due date (it's project time zone, not current user timezone)
    init(timeZone: TimeZone) {
        self.timeZone = timeZone
        super.init(frame: .zero)

        setupButton()
        updateButton()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setDueDate(_ dueDate: Date?, markOverdue: Bool) {
        self.dueDate = dueDate
        self.markOverdue = markOverdue
        updateButton()
    }

    /// Update the content when due date change
    private func updateButton() {
        updateTitle()
        updateImage()
        updateColors()
    }

    override open var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted
                ? .dynamic(.Neutral_07)
                : .dynamic(.Neutral_09)
        }
    }

    /// Setup the button configuration
    private func setupButton() {
        // because of a bug that doesn't allow for limiting the number of lines for
        // UIButton title to 1 for buttons configured using UIButton.Configuration
        // we need to use the old way of configuring the button
        // bug: https://developer.apple.com/forums/thread/699622
        setInsets(
            forContentPadding: UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8),
            imageTitlePadding: 8
        )
        contentHorizontalAlignment = .leading
        titleLabel?.numberOfLines = 2
        titleLabel?.lineBreakMode = .byTruncatingTail

        backgroundColor = .dynamic(.Neutral_09)
        layer.cornerRadius = 8
        layer.borderWidth = 1

        updateColors()
    }

    /// update colors
    override func traitCollectionDidChange(_: UITraitCollection?) {
        updateTitle()
        updateImage()
        updateColors()
    }

    private func updateColors() {
        layer.borderColor = markOverdue
            ? UIColor.Red_03.cgColor
            : chooseColor(.Neutral_07).cgColor
    }

    /// Updates the title (both, the content and colors)
    private func updateTitle() {
        if let dueDate = dueDate {
            // we cannot use UIButton.subtitle, it's only supported when using configuration
            // so let's make a 2 line title (and title is limited to 2 lines so if the
            // due date is too long it'll be truncated)
            let title = NSMutableAttributedString(
                string: "Due date\n",
                attributes: [
                    .foregroundColor: markOverdue
                        ? UIColor.Red_03
                        : chooseColor(.Neutral_05),
                    .font: UIFont._preferredFont(forTextStyle: .caption2, symbolicTraits: .traitBold),
                ]
            )
            title
                .append(NSAttributedString(string: Date.dueDateFormat(dueDate, timeZone: timeZone),
                                           attributes: [
                                               .foregroundColor: markOverdue
                                                   ? UIColor.Red_03
                                                   : chooseColor(.Neutral_04),
                                               .font: UIFont._preferredFont(
                                                   forTextStyle: .subheadline,
                                                   symbolicTraits: .traitBold
                                               ),
                                           ]))
            setAttributedTitle(title, for: .normal)
        } else {
            let title = NSMutableAttributedString(
                string: "Due Date",
                attributes: [
                    .foregroundColor: markOverdue
                        ? UIColor.Red_03
                        : chooseColor(.Neutral_05),
                    .font: UIFont._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold),
                ]
            )
            setAttributedTitle(title, for: .normal)
        }
    }

    /// setup the calendar image
    private func updateImage() {
        let image = UIImage(
            systemName: "calendar",
            withConfiguration: UIImage
                .SymbolConfiguration(font: UIFont
                    ._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold))
        )?
            .withTintColor(markOverdue ? .Red_03 : chooseColor(.Neutral_04),
                           renderingMode: .alwaysTemplate)
        let imageWithBackground = image?.addCircleBackground(
            bgSize: CGSize(width: 32, height: 32),
            bgColor: chooseColor(.Neutral_10),
            strokeColor: markOverdue
                ? .Red_03
                : chooseColor(.Neutral_07)
        )
        setImage(imageWithBackground, for: .normal)
        setImage(imageWithBackground, for: .highlighted)
    }
}
