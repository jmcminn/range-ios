import Foundation
import UIKit

/// The table view cell to show the updated value of name (or a description)
class NameUpdateFeedItemCell: UITableViewCell {
    weak var tableView: UITableView?
    private let messageLabel = UILabel()
    private let previousValueLabel = LabelWithTextInsets()
    /// whether the cell is showing the previous value
    private var showingPrevious = false {
        didSet {
            updatePreviousValueVisibility()
        }
    }

    var update: Update? {
        didSet {
            updateMessage()
            if let update = update {
                previousValueLabel.text = "\"\(update.oldValue.stringValue ?? "")\""
            } else {
                previousValueLabel.text = nil
            }
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)

        selectionStyle = .none

        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        contentView.addSubview(messageLabel)
        messageLabel.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(CollaborationFeedViewController.distanceBetweenRows / 2)
                .priority(.required)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        previousValueLabel.textInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        previousValueLabel.textColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_04)
        previousValueLabel.font = ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitItalic)
        previousValueLabel.numberOfLines = 0
        previousValueLabel.lineBreakMode = .byWordWrapping
        previousValueLabel.backgroundColor = .dynamicColor(light: .Neutral_03, dark: .Neutral_08)
        previousValueLabel.layer.borderWidth = 1
        previousValueLabel.layer.cornerRadius = 16
        previousValueLabel.clipsToBounds = true
        contentView.addSubview(previousValueLabel)

        updateColors()
        updatePreviousValueVisibility()

        contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleShowingPrevious)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func toggleShowingPrevious() {
        showingPrevious = !showingPrevious
    }

    /// Updates the text of the message. Changes when user toggles showing the previous value
    private func updateMessage() {
        if let update = update {
            let messageString = NSMutableAttributedString(
                string: update.user?.displayName ?? "",
                attributes: [
                    .foregroundColor: chooseColor(light: .Neutral_06, dark: .Neutral_05),
                    .font: UIFont._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold),
                ]
            )
            let messageText = " changed the \(update.field.rawValue) \(TimeInterval.format2(update.timestamp))."
            messageString.append(NSAttributedString(string: messageText, attributes: [
                .foregroundColor: chooseColor(light: .Neutral_06, dark: .Neutral_05),
                .font: UIFont.preferredFont(forTextStyle: .caption2),
            ]))
            let togglePreviousText = showingPrevious ? " Hide previous" : " Show previous"
            messageString.append(NSAttributedString(string: togglePreviousText, attributes: [
                .foregroundColor: UIColor.Primary_Blue_04,
                .font: UIFont.preferredFont(forTextStyle: .caption2),
            ]))
            messageLabel.attributedText = messageString
        } else {
            messageLabel.attributedText = nil
        }
    }

    /// updates the constraints to show / hide the previous value label
    private func updatePreviousValueVisibility() {
        updateMessage()
        if showingPrevious {
            previousValueLabel.snp.remakeConstraints { make in
                make.top.equalTo(messageLabel.snp.bottom).offset(8)
                make.leading.trailing.equalToSuperview().inset(16)
                make.bottom.lessThanOrEqualToSuperview().inset(CollaborationFeedViewController.distanceBetweenRows / 2)
                    .priority(.high)
            }
        } else {
            previousValueLabel.snp.remakeConstraints { make in
                make.top.equalTo(messageLabel.snp.bottom).offset(8)
                make.leading.trailing.equalToSuperview().inset(16)
                make.height.equalTo(0)
                // there's already 8 points between the message and previous labels, so the bottom space needs -8
                make.bottom.lessThanOrEqualToSuperview()
                    .inset(CollaborationFeedViewController.distanceBetweenRows / 2 - 8)
                    .priority(.high)
            }
        }
        tableView?.beginUpdates()
        tableView?.endUpdates()
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        updateColors()
    }

    /// Update colors that doesn't automatically adapt to appearance change
    private func updateColors() {
        previousValueLabel.layer.borderColor = chooseColor(light: .Neutral_04, dark: .Neutral_07).cgColor
    }

    override func prepareForReuse() {
        update = nil
        showingPrevious = false
    }
}
