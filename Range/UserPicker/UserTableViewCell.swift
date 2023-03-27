import Foundation
import UIKit

class UserTableViewCell: UITableViewCell {
    let avatarView = UIView()
    let nameLabel = UILabel()
    let emailLabel = UILabel()
    let selectedIconView = UIImageView(image: UIImage(named: "checkmark_checked"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in the view controller

        setupViews()
        [avatarView, nameLabel, emailLabel, selectedIconView].forEach(contentView.addSubview)

        avatarView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
            make.leading.equalTo(contentView.snp.leadingMargin).offset(12)
        }
        nameLabel.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview().offset(11)
            make.bottom.equalTo(contentView.snp.centerY).offset(2)
            make.leading.equalTo(contentView.snp.leadingMargin).offset(52)
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(16)
        }
        emailLabel.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom)
            make.bottom.lessThanOrEqualToSuperview().offset(-11)
            make.leading.equalTo(contentView.snp.leadingMargin).offset(52)
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(16)
        }
        selectedIconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(12)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        avatarView.layer.cornerRadius = 16
        avatarView.backgroundColor = .dynamic(.Neutral_07)

        nameLabel.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        nameLabel.font = .preferredFont(forTextStyle: .body)

        emailLabel.textColor = .dynamic(.Neutral_05)
        emailLabel.font = ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
    }

    func setUser(_ user: Participant, selected: Bool) {
        nameLabel.text = user.displayName
        emailLabel.text = user.email
        selectedIconView.isHidden = !selected
    }

    override func prepareForReuse() {
        nameLabel.text = nil
        emailLabel.text = nil
        selectedIconView.isHidden = true
    }
}
