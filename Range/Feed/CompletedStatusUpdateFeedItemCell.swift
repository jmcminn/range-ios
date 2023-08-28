import Foundation
import UIKit

/// The table view cell to show the special version of Status update for completed status
class CompletedStatusUpdateFeedItemCell: UITableViewCell {
    private let checkView = UIView()
    private let messageLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear

        selectionStyle = .none

        checkView.layer.cornerRadius = 16
        contentView.addSubview(checkView)
        checkView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
            make.leading.equalToSuperview().inset(16)
        }
        let checkImageView = UIImageView(image: UIImage(named: "tick.small"))
        checkView.addSubview(checkImageView)
        checkImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        contentView.addSubview(messageLabel)
        messageLabel.snp.remakeConstraints { make in
            make.leading.equalToSuperview().inset(FeedItemCells.leadingContentLayoutMargin)
            make.trailing.equalToSuperview().inset(16).priority(.required)
            make.top.greaterThanOrEqualToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
            make.centerY.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Updates the text of the message.
    func set(update: Update, status: Status) {
        checkView.backgroundColor = status.color

        let messageString = NSMutableAttributedString(
            string: update.user?.displayName ?? "",
            attributes: [
                .foregroundColor: status.color,
                .font: UIFont._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold),
                .strikethroughStyle: update.user?.strikethroughStyle ?? 0,
            ]
        )
        messageString.append(NSAttributedString(
            string: " completed this issue \(Date.format3(update.timestamp)).",
            attributes: [
                .foregroundColor: status.color,
                .font: UIFont.preferredFont(forTextStyle: .footnote),
            ]
        ))
        messageLabel.attributedText = messageString
    }

    override func prepareForReuse() {
        messageLabel.attributedText = nil
    }
}
