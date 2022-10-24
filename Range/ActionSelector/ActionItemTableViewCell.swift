import Foundation
import UIKit

/// Table view cell for displaying ActionItem
class ActionItemTableViewCell: UITableViewCell {
    private let iconView = UIImageView()
    private let titleView = UILabel()
    private static let imageConfig = UIImage.SymbolConfiguration(textStyle: .footnote)
        .applying(UIImage.SymbolConfiguration(weight: .medium))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in the view controller

        contentView.addSubview(iconView)
        contentView.addSubview(titleView)

        iconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.centerX.equalTo(contentView.snp.leadingMargin).offset(24)
        }
        titleView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(contentView.snp.leadingMargin).offset(44)
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
                    : .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
                iconView.tintColor = actionColor
                titleView.textColor = actionColor
                titleView.text = actionItem.title
                if let imageName = actionItem.imageName {
                    iconView.image = UIImage(
                        systemName: imageName,
                        withConfiguration: ActionItemTableViewCell.imageConfig
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
