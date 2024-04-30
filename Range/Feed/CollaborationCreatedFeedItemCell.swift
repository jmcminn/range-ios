import Foundation
import UIKit

/// The table view cell to show "collaboration created" feed item
class CollaborationCreatedFeedItemCell: UITableViewCell {
    let avatarView = AvatarView()
    let messageLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear

        selectionStyle = .none

        contentView.addSubview(avatarView)
        avatarView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
            make.leading.equalToSuperview().inset(16)
        }

        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        contentView.addSubview(messageLabel)
        messageLabel.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().inset(FeedItemCells.leadingContentLayoutMargin)
            make.trailing.equalToSuperview().inset(16)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(collaboration: Collaboration) {
        avatarView.setAvatar(forParticipant: collaboration.author)
        let messageString = NSMutableAttributedString(
            string: collaboration.author?.displayName ?? "",
            attributes: [
                .foregroundColor: chooseColor(.Neutral_04),
                .font: UIFont._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold),
                .strikethroughStyle: collaboration.author?.strikethroughStyle ?? 0,
            ]
        )
        let messageText = " created this pin " + Date.format3(collaboration.timestamp)
        messageString.append(NSAttributedString(string: messageText, attributes: [
            .foregroundColor: chooseColor(.Neutral_05),
            .font: UIFont.preferredFont(forTextStyle: .footnote),
        ]))
        messageLabel.attributedText = messageString
    }

    override func prepareForReuse() {
        avatarView.setAvatar(forParticipant: nil)
        messageLabel.attributedText = nil
    }
}
