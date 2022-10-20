import Foundation
import UIKit

/// The table view cell to show the generic update of status
class StatusUpdateFeedItemCell: UITableViewCell {
    private let messageLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)

        selectionStyle = .none

        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        contentView.addSubview(messageLabel)
        messageLabel.snp.remakeConstraints { make in
            make.top.equalToSuperview().priority(.required)
            make.bottom.lessThanOrEqualToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
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

        // the space is needed at the end, otherwise the timestamp is always word wrapped together
        // with the status attachment. If a space is added after timestamp it makes the label
        // render the status at the end of the line and timestamp on new line... Adding it as a non
        // braking space so it doesn't end up rendered as the only character in the new line.
        let nonBrakingSpace = " "
        messageString
            .append(NSAttributedString(string: "  \(TimeInterval.format2(update.timestamp)).\(nonBrakingSpace)",
                                       attributes: textAttributes))
        messageLabel.attributedText = messageString
    }

    override func prepareForReuse() {
        messageLabel.attributedText = nil
    }
}
