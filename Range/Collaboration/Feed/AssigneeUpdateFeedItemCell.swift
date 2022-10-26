import Foundation
import UIKit

/// The table view cell to show the assignee update
class AssigneeUpdateFeedItemCell: UITableViewCell {
    private let messageLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)

        selectionStyle = .none

        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        contentView.addSubview(messageLabel)
        messageLabel.snp.remakeConstraints { make in
            make.top.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Updates the text of the message.
    func set(update: Update, oldAssignee: Participant?, newAssignee: Participant?) {
        let messageString = NSMutableAttributedString(
            string: update.user?.displayName ?? "",
            attributes: [
                .foregroundColor: chooseColor(light: .Neutral_06, dark: .Neutral_04),
                .font: UIFont._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold),
            ]
        )
        let message: String
        if let newAssignee = newAssignee {
            if oldAssignee == nil {
                message = "assigned to \(newAssignee.displayName)"
            } else {
                message = "changed the assignee to \(newAssignee.displayName)"
            }
        } else {
            message = "removed the assignee"
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
