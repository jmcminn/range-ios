import Foundation
import UIKit

class ItemPickerTableViewCell: UITableViewCell {
    /// The cell has 2 variants based on the reuseIdentifier
    enum Variant: String {
        case single = "ItemCell"
        case multi = "MultiselectItemCell"

        static func identifier(forMultiselect: Bool) -> String {
            forMultiselect ? multi.rawValue : single.rawValue
        }
    }

    let nameLabel = UILabel()
    let pinkDot = UIView()
    let selectedIconView = UIImageView(image: UIImage(named: "checkmark_checked"))
    private let multiselect: Bool

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        multiselect = reuseIdentifier == Variant.identifier(forMultiselect: true)
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in the view controller

        setupViews()
        [nameLabel, pinkDot, selectedIconView].forEach(contentView.addSubview)

        nameLabel.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview().offset(11)
            make.bottom.lessThanOrEqualToSuperview().offset(-11)
            make.leading.equalTo(contentView.snp.leadingMargin).offset(multiselect ? 44 : 12)
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(16)
        }
        pinkDot.snp.makeConstraints { make in
            make.width.height.equalTo(8)
            make.centerY.equalToSuperview()
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(12)
        }
        selectedIconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            if multiselect {
                make.leading.equalTo(contentView.snp.leadingMargin).inset(12)
            } else {
                make.trailing.equalTo(contentView.snp.trailingMargin).inset(12)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        nameLabel.textColor = .dynamic(.Neutral_04)
        nameLabel.font = .preferredFont(forTextStyle: .body)
        
        pinkDot.backgroundColor = .Pink_03
        pinkDot.layer.cornerRadius = 4
    }

    func setItem(_ item: ItemPickerItem) {
        nameLabel.text = item.name
        if multiselect {
            selectedIconView.isHidden = false
            selectedIconView.image = item.selected
                ? UIImage(named: "checkmark_checked")
                : UIImage().addCircleBackground(bgSize: CGSize(width: 20, height: 20),
                                                bgColor: .dynamic(.Neutral_10),
                                                strokeColor: .dynamic(.Neutral_07))
        } else {
            selectedIconView.isHidden = !item.selected
        }
        pinkDot.isHidden = !item.marked
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        selectedIconView.isHidden = true
        pinkDot.isHidden = true
    }
}
