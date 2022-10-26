import Foundation
import UIKit

/// The table view cell to show "collaboration created" feed item
class CollaborationCreatedFeedItemCell: UITableViewCell {
    let avatarView = UIView()
    let messageLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)

        selectionStyle = .none

        avatarView.layer.cornerRadius = 16
        avatarView.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)
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
            make.leading.equalTo(avatarView.snp.trailing).offset(8)
            make.trailing.equalToSuperview().inset(16)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(collaboration: Collaboration) {
        let messageString = NSMutableAttributedString(
            string: collaboration.author?.displayName ?? "",
            attributes: [
                .foregroundColor: chooseColor(light: .Neutral_06, dark: .Neutral_04),
                .font: UIFont._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold),
            ]
        )
        var messageText = " created this issue"
        if let timestamp = collaboration.timestamp {
            messageText += " " + TimeInterval.format3(timestamp)
        }
        messageString.append(NSAttributedString(string: messageText, attributes: [
            .foregroundColor: chooseColor(light: .Neutral_06, dark: .Neutral_05),
            .font: UIFont.preferredFont(forTextStyle: .footnote),
        ]))
        messageLabel.attributedText = messageString
    }

    override func prepareForReuse() {
        messageLabel.attributedText = nil
    }
}
