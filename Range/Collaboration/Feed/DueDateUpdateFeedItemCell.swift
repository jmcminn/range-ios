import Foundation
import UIKit

/// The table view cell to show the due date update
class DueDateUpdateFeedItemCell: UITableViewCell {
    private let messageLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)

        selectionStyle = .none

        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        contentView.addSubview(messageLabel)
        messageLabel.snp.remakeConstraints { make in
            make.leading.equalToSuperview().inset(FeedItemCells.leadingContentLayoutMargin)
            make.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().priority(.required)
            make.bottom.lessThanOrEqualToSuperview()
        }

        let dotView = FeedItemCells.minorItemDotView()
        contentView.addSubview(dotView)
        dotView.snp.makeConstraints { make in
            make.centerX.equalTo(contentView.snp.leading).offset(FeedItemCells.leadingVerticalLineMargin)
            make.top.equalTo(messageLabel.snp.top).offset(4)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Updates the text of the message.
    func set(update: Update) {
        let messageString = NSMutableAttributedString(
            string: update.user?.displayName ?? "",
            attributes: [
                .foregroundColor: chooseColor(light: .Neutral_06, dark: .Neutral_04),
                .font: UIFont._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold),
            ]
        )
        let message: String
        if let newDueDateInt = update.newValue.intValue {
            let newDueDate = TimeInterval(newDueDateInt) / 1000
            let newDueDateString = TimeInterval.dueDateFormat(newDueDate)
            if update.oldValue.intValue == nil {
                message = "added a due date of \(newDueDateString)"
            } else {
                message = "changed the due date to \(newDueDateString)"
            }
        } else {
            message = "removed the due date"
        }
        messageString.append(NSAttributedString(
            string: " \(message) \(TimeInterval.format2(update.timestamp)).",
            attributes: [
                .foregroundColor: chooseColor(light: .Neutral_06, dark: .Neutral_05),
                .font: UIFont.preferredFont(forTextStyle: .footnote),
            ]
        ))
        messageLabel.attributedText = messageString
    }

    override func prepareForReuse() {
        messageLabel.attributedText = nil
    }
}
