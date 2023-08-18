import Foundation
import UIKit

/// A button that displays given date or a placeholder text depending on the configured variant
class DateButton: UIButton {
    private(set) var date: Date?

    /// defines variants of this button, currently either a "from" or "to" date
    enum Variant {
        case from, to
    }

    private let variant: Variant

    /// - Parameters:
    ///     - timezone: the timezone in which to display the due date (it's project time zone, not current user timezone)
    init(variant: Variant) {
        self.variant = variant
        super.init(frame: .zero)

        setupButton()
        updateButton()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setDate(_ date: Date?) {
        self.date = date
        updateButton()
    }

    /// Update the content when due date change
    private func updateButton() {
        updateTitle()
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
        contentHorizontalAlignment = .center
        titleLabel?.numberOfLines = 2
        titleLabel?.lineBreakMode = .byTruncatingTail

        backgroundColor = .dynamic(.Neutral_09)
        layer.cornerRadius = 12
        layer.borderWidth = 1

        let image = UIImage(
            systemName: "calendar",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)
        )?.withRenderingMode(.alwaysTemplate)
        setImage(image, for: .normal)
        setImage(image, for: .highlighted)
        tintColor = .dynamic(.Neutral_05)

        updateColors()
    }

    /// update colors
    override func traitCollectionDidChange(_: UITraitCollection?) {
        updateTitle()
        updateColors()
    }

    private func updateColors() {
        layer.borderColor = chooseColor(.Neutral_07).cgColor
    }

    /// Updates the title (both, the content and colors)
    private func updateTitle() {
        if let date = date {
            // we cannot use UIButton.subtitle, it's only supported when using configuration
            // so let's make a 2 line title (and title is limited to 2 lines so if the
            // due date is too long it'll be truncated)
            let title = NSMutableAttributedString(string: Date.dueDateFormat(date, timeZone: nil), attributes: [
                .foregroundColor: chooseColor(.Neutral_04),
                .font: UIFont.preferredFont(forTextStyle: .body),
            ])
            setAttributedTitle(title, for: .normal)
        } else {
            let title = NSMutableAttributedString(string: variant == .from ? "From" : "To", attributes: [
                .foregroundColor: chooseColor(.Neutral_04),
                .font: UIFont.preferredFont(forTextStyle: .body),
            ])
            title.append(NSAttributedString(string: " (Any)", attributes: [
                .foregroundColor: chooseColor(.Neutral_05),
                .font: UIFont.preferredFont(forTextStyle: .body),
            ]))
            setAttributedTitle(title, for: .normal)
        }
    }
}
