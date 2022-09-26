import Foundation
import RealmSwift
import SnapKit
import UIKit

/// The table view cell to show comment feed item
class CommentFeedItemCell: UITableViewCell {
    let avatarView = UIView()
    let authorLabel = UILabel()
    let timestampLabel = UILabel()
    let commentTextLabel = UILabel()

    /// for animating cell height when the content changes
    weak var tableView: UITableView?

    /// listen to changes in upload and the content
    private var notificationToken: NotificationToken?

    unowned var comment: Comment? {
        didSet {
            updateContent()
            if let comment = comment {
                // not observe again if already observing
                if let previousComment = oldValue, previousComment.id == comment.id {
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.notificationToken = comment.observe { [weak self] change in
                        if case .deleted = change {
                            self?.comment = nil
                        } else {
                            DispatchQueue.main.async { [weak self] in
                                self?.updateContent()
                                guard let tableView = self?.tableView else { return }
                                tableView.beginUpdates()
                                tableView.endUpdates()
                            }
                        }
                    }
                }
            } else {
                notificationToken?.invalidate()
            }
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)

        selectionStyle = .none

        setupViews()

        [avatarView, authorLabel, timestampLabel, commentTextLabel].forEach(contentView.addSubview)

        avatarView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(CollaborationFeedViewController.distanceBetweenRows / 2)
            make.width.height.equalTo(32)
            make.leading.equalToSuperview().inset(16)
        }
        authorLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(8)
            make.bottom.equalTo(avatarView.snp.centerY)
        }
        timestampLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(8)
            make.top.equalTo(avatarView.snp.centerY)
        }
        commentTextLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(avatarView.snp.bottom).offset(12)
            make.bottom.equalToSuperview().inset(CollaborationFeedViewController.distanceBetweenRows / 2)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        avatarView.layer.cornerRadius = 16
        avatarView.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)

        authorLabel.textColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_04)
        authorLabel.font = UIFont._preferredFont(forTextStyle: .callout, symbolicTraits: .traitBold)

        timestampLabel.textColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_05)
        timestampLabel.font = .preferredFont(forTextStyle: .footnote)

        commentTextLabel.textColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_04)
        commentTextLabel.font = .preferredFont(forTextStyle: .subheadline)
        commentTextLabel.numberOfLines = 0
        commentTextLabel.lineBreakMode = .byWordWrapping
    }

    override func prepareForReuse() {
        comment = nil
    }

    /// Called whenever a comment is set for the cell or updated
    /// Updates all the fields
    private func updateContent() {
        authorLabel.text = comment?.author?.displayName
        if let timestamp = comment?.timestamp {
            timestampLabel.text = TimeInterval.format1(timestamp)
        } else {
            timestampLabel.text = nil
        }
        commentTextLabel.text = comment?.text
    }
}
