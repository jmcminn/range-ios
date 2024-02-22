import Foundation
import Knock
import UIKit

class InAppFeedItemTableViewCell: UITableViewCell {
    /// The cell has 2 variants based on the reuseIdentifier
    enum Variant: String {
        case organization = "Organization"
        case project = "Project"
    }

    private let unreadMarker = UIView()
    private let avatarView = UIView()
    private let label = UILabel()
    private let insertedAtLabel = UILabel()
    private let bottomStroke = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .dynamic(.Neutral_09)
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .dynamic(.Neutral_08)

        setupViews()

        [unreadMarker, avatarView, label, insertedAtLabel, bottomStroke].forEach(contentView.addSubview)

        unreadMarker.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(12)
            make.leading.equalToSuperview().inset(8)
            make.width.height.equalTo(8)
        }

        avatarView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16)
            make.leading.equalToSuperview().inset(18)
            make.width.height.equalTo(32)
        }

        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(58)
            make.top.trailing.equalToSuperview().inset(12)
        }

        insertedAtLabel.snp.makeConstraints { make in
            make.top.equalTo(label.snp.bottom).offset(4)
            make.leading.equalToSuperview().inset(58)
            make.bottom.trailing.equalToSuperview().inset(12)
        }

        bottomStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        unreadMarker.backgroundColor = .Special_01
        unreadMarker.layer.cornerRadius = 4
        unreadMarker.isHidden = true

        avatarView.backgroundColor = .dynamic(.Neutral_08)
        avatarView.layer.cornerRadius = 16
        avatarView.isHidden = true

        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .dynamic(.Neutral_04)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0

        insertedAtLabel.font = .preferredFont(forTextStyle: .footnote)
        insertedAtLabel.textColor = .dynamic(.Neutral_05)
        insertedAtLabel.adjustsFontForContentSizeCategory = true

        bottomStroke.backgroundColor = .dynamic(.Neutral_07)
    }

    func setFeedItem(_ item: Knock.FeedItem) {
        unreadMarker.isHidden = item.read_at != nil
        avatarView.isHidden = false
        label.text = item.blocks.first?.rendered
        insertedAtLabel.text = if let inserted_at = item.inserted_at { Date.format1Ago(inserted_at) } else { "" }
    }

    override func prepareForReuse() {
        unreadMarker.isHidden = true
        avatarView.isHidden = true
        label.text = nil
        insertedAtLabel.text = ""
    }
}
