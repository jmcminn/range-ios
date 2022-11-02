import Foundation
import UIKit

/// The table view cell to show the generic update of status
class StatusUpdateFeedItemCell: UITableViewCell {
    private let messageLabel = UILabel()

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
    func set(update: Update, status: Status) {
        let messageString = NSMutableAttributedString(
            string: update.user?.displayName ?? "",
            attributes: [
                .foregroundColor: chooseColor(light: .Neutral_06, dark: .Neutral_04),
                .font: UIFont._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold),
            ]
        )
        let textAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: chooseColor(light: .Neutral_06, dark: .Neutral_05),
            .font: UIFont.preferredFont(forTextStyle: .footnote),
        ]
        // There are 2 spaces between and after the status attachment - we want more distance there
        messageString.append(NSAttributedString(string: " changed the status to  ",
                                                attributes: textAttributes))

        // show the status bubble - it's a view converted to image, added as a text attachment
        let statusView = StatusView(status: status)
        let statusAttachment = NSTextAttachment(image: statusView.asImage())
        // align the status view to it's text label
        let statusAttachmentBoundsY = statusView.textLabel.font.descender - statusView.textLabel.textInsets.bottom
        statusAttachment.bounds = CGRect(
            x: 0,
            y: statusAttachmentBoundsY,
            width: statusView.frame.width,
            height: statusView.frame.height
        )
        messageString.append(NSAttributedString(attachment: statusAttachment))

        // the non braking space is needed before the timestamp, otherwise the timestamp is sometimes
        // word wrapped together with the status attachment if the timestamp is one word only (like
        // 'today' or 'yesterday'.
        // The side effect is that if 'today' starts the 2nd line it has a small indentation comparing
        // to 1st line because of the non braking space but that's acceptable.
        let nonBrakingSpace = " "
        messageString
            .append(
                NSAttributedString(
                    string: " \(nonBrakingSpace)\(Date.format2(update.timestamp)).",
                    attributes: textAttributes
                )
            )
        messageLabel.attributedText = messageString
    }

    override func prepareForReuse() {
        messageLabel.attributedText = nil
    }
}
