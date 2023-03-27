import Foundation
import UIKit

/// Table view cell for displaying ActionItem
class ActionItemTableViewCell: UITableViewCell {
    private let iconView = UIImageView()
    private let titleView = UILabel()
    private var imageFont: UIFont {
        .preferredFont(forTextStyle: .footnote)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in the view controller

        titleView.numberOfLines = 0
        titleView.font = .preferredFont(forTextStyle: .body)

        contentView.addSubview(iconView)
        contentView.addSubview(titleView)

        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(imageFont.lineHeight)
            make.centerY.equalToSuperview()
            make.leading.equalTo(contentView.snp.leadingMargin).offset(12)
        }
        titleView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(14)
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(16)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    weak var actionItem: ActionItem? {
        didSet {
            if let actionItem = actionItem {
                let actionColor: UIColor = actionItem.style == .destructive
                    ? .Red_03
                    : .dynamic(.Neutral_04)
                iconView.tintColor = actionColor
                iconView.contentMode = .scaleAspectFit
                titleView.textColor = actionColor
                titleView.text = actionItem.title
                if let imageName = actionItem.imageName {
                    iconView.image = UIImage(
                        systemName: imageName,
                        withConfiguration: UIImage.SymbolConfiguration(font: imageFont)
                    )
                }
            } else {
                iconView.image = nil
                titleView.text = nil
            }
        }
    }

    override func prepareForReuse() {
        actionItem = nil
    }
}
