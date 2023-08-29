import Foundation
import UIKit

class UserTableViewCell: UITableViewCell {
    /// The cell has 2 variants based on the reuseIdentifier
    enum Variant: String {
        case single = "UserCell"
        case multi = "MultiUserCell"

        static func identifier(forMultiselect: Bool) -> String {
            forMultiselect ? multi.rawValue : single.rawValue
        }
    }

    let avatarView = UIView()
    let nameLabel = UILabel()
    let emailLabel = UILabel()
    let selectedIconView = UIImageView(image: UIImage(named: "checkmark_checked"))
    private let multiselect: Bool

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        multiselect = reuseIdentifier == Variant.identifier(forMultiselect: true)
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in the view controller

        setupViews()
        [avatarView, nameLabel, emailLabel, selectedIconView].forEach(contentView.addSubview)

        avatarView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview().offset(14)
            make.bottom.lessThanOrEqualToSuperview().offset(-14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
            make.leading.equalTo(contentView.snp.leadingMargin).offset(multiselect ? 44 : 12)
        }
        nameLabel.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview().offset(11)
            make.bottom.equalTo(contentView.snp.centerY).offset(2)
            make.leading.equalTo(contentView.snp.leadingMargin).offset(multiselect ? 84 : 52)
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(16)
        }
        emailLabel.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom)
            make.bottom.lessThanOrEqualToSuperview().offset(-11)
            make.leading.equalTo(contentView.snp.leadingMargin).offset(multiselect ? 84 : 52)
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(16)
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
        avatarView.layer.cornerRadius = 16
        avatarView.backgroundColor = .dynamic(.Neutral_07)

        nameLabel.textColor = .dynamic(.Neutral_04)
        nameLabel.font = .preferredFont(forTextStyle: .body)

        emailLabel.textColor = .dynamic(.Neutral_05)
        emailLabel.font = ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
    }

    func setUser(_ user: UserViewModel) {
        nameLabel.attributedText = NSAttributedString(
            string: user.name,
            attributes: [.strikethroughStyle: user.strikethroughStyle]
        )
        if user.suspended {
            // don't show email if user is suspended
            nameLabel.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalTo(contentView.snp.leadingMargin).offset(multiselect ? 84 : 52)
                make.trailing.equalTo(contentView.snp.trailingMargin).inset(16)
            }
            emailLabel.isHidden = true
            emailLabel.text = nil
        } else {
            nameLabel.snp.remakeConstraints { make in
                make.top.greaterThanOrEqualToSuperview().offset(11)
                make.bottom.equalTo(contentView.snp.centerY).offset(2)
                make.leading.equalTo(contentView.snp.leadingMargin).offset(multiselect ? 84 : 52)
                make.trailing.equalTo(contentView.snp.trailingMargin).inset(16)
            }
            emailLabel.isHidden = false
            emailLabel.text = user.email
        }
        if multiselect {
            selectedIconView.isHidden = false
            selectedIconView.image = user.selected
                ? UIImage(named: "checkmark_checked")
                : UIImage().addCircleBackground(bgSize: CGSize(width: 20, height: 20),
                                                bgColor: .dynamic(.Neutral_10),
                                                strokeColor: .dynamic(.Neutral_07))
        } else {
            selectedIconView.isHidden = !user.selected
        }
    }

    override func prepareForReuse() {
        nameLabel.attributedText = nil
        emailLabel.text = nil
        selectedIconView.isHidden = true
    }
}
