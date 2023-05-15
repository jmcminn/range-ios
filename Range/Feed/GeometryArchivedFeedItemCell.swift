import Foundation
import UIKit

/// The table view cell to show when the geometry was archived
class GeometryArchivedFeedItemCell: UITableViewCell {
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
            make.top.equalToSuperview()
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
    func set(geometry: Geometry) {
        if let archivedTimestamp = geometry.archivedTimestamp {
            messageLabel.attributedText = NSAttributedString(
                string: "This pin was archived \(Date.format2(archivedTimestamp))",
                attributes: [
                    .foregroundColor: chooseColor(.Neutral_05),
                    .font: UIFont.preferredFont(forTextStyle: .footnote),
                ]
            )
        }
    }

    override func prepareForReuse() {
        messageLabel.attributedText = nil
    }
}
