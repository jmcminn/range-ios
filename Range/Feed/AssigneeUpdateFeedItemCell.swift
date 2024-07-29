import Foundation
import UIKit

/// The table view cell to show the assignee update
class AssigneeUpdateFeedItemCell: UITableViewCell {
    private let messageLabel = UILabel()
    private var userNameFont: UIFont {
        UIFont._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear

        selectionStyle = .none

        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        contentView.addSubview(messageLabel)
        messageLabel.snp.remakeConstraints { make in
            make.leading.equalToSuperview().inset(FeedItemCells.leadingContentLayoutMargin)
            make.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }

        let dotView = FeedItemCells.minorItemDotView()
        contentView.addSubview(dotView)
        dotView.snp.makeConstraints { make in
            make.centerX.equalTo(contentView.snp.leading).offset(FeedItemCells.leadingVerticalLineMargin)
            make.centerY.equalTo(messageLabel.snp.firstBaseline).offset(-userNameFont.capHeight / 2.0)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Updates the text of the message.
    ///
    func set(update: Update, oldAssignee: Participant?, newAssignee: Participant?) {
        let messageString = NSMutableAttributedString(
            string: update.user?.displayName ?? "",
            attributes: [
                .foregroundColor: chooseColor(.Neutral_05),
                .font: userNameFont,
                .strikethroughStyle: update.user?.strikethroughStyle ?? 0,
            ]
        )
        let messageAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: chooseColor(.Neutral_05),
            .font: UIFont.preferredFont(forTextStyle: .footnote),
        ]
        if let newAssignee = newAssignee {
            if oldAssignee == nil {
                messageString.append(NSAttributedString(string: " assigned to ", attributes: messageAttributes))
            } else {
                messageString.append(
                    NSAttributedString(string: " changed the assignee to ", attributes: messageAttributes)
                )
            }
            var newAssigneeAttributes = messageAttributes
            newAssigneeAttributes[.strikethroughStyle] = newAssignee.strikethroughStyle
            messageString.append(NSAttributedString(
                string: newAssignee.displayName,
                attributes: newAssigneeAttributes
            ))
        } else {
            messageString.append(NSAttributedString(string: " removed the assignee", attributes: messageAttributes))
        }
        messageString.append(NSAttributedString(
            string: " \(Date.format2(update.createdAt)).",
            attributes: messageAttributes
        ))
        messageLabel.attributedText = messageString
    }

    override func prepareForReuse() {
        messageLabel.attributedText = nil
    }
}
