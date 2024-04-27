import Foundation
import UIKit

class OrganizationTableViewCell: UITableViewCell {
    let badgeLabel = UILabel()
    let iconView = UIImageView()
    let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in the view controller

        setupViews()
        [badgeLabel, iconView, nameLabel].forEach(contentView.addSubview)

        badgeLabel.snp.makeConstraints { make in
            make.width.height.equalTo(32)
            make.top.greaterThanOrEqualToSuperview().offset(13)
            make.bottom.lessThanOrEqualToSuperview().offset(-13)
            make.centerY.equalToSuperview()
            make.leading.equalTo(contentView.snp.leadingMargin).inset(16)
        }

        iconView.snp.makeConstraints { make in
            make.edges.equalTo(badgeLabel)
        }

        nameLabel.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview().offset(13)
            make.bottom.lessThanOrEqualToSuperview().offset(-13)
            make.centerY.equalToSuperview()
            make.leading.equalTo(badgeLabel.snp.trailing).offset(8)
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(16)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        nameLabel.textColor = .dynamic(.Neutral_04)
        nameLabel.font = .preferredFont(forTextStyle: .body)

        badgeLabel.font = .systemFont(ofSize: 14)
        badgeLabel.textColor = .dynamic(.Neutral_05)
        badgeLabel.layer.borderWidth = 1
        badgeLabel.layer.borderColor = chooseColor(.Neutral_07).cgColor
        badgeLabel.backgroundColor = .dynamic(.Neutral_10)
        badgeLabel.layer.cornerRadius = 16
        badgeLabel.clipsToBounds = true
        badgeLabel.textAlignment = .center

        iconView.layer.borderWidth = 1
        iconView.layer.borderColor = chooseColor(.Neutral_07).cgColor
        iconView.backgroundColor = .dynamic(.Neutral_10)
        iconView.layer.cornerRadius = 16
        iconView.clipsToBounds = true
        iconView.contentMode = .scaleAspectFit
    }

    func setOrganization(_ organization: Organization, selected _: Bool) {
        if let iconImage = organization.iconImage {
            iconView.image = iconImage
            iconView.isHidden = false
            badgeLabel.isHidden = true
        } else {
            badgeLabel.text = organization.name.prefix(1).uppercased()
            iconView.isHidden = true
            badgeLabel.isHidden = false
        }
        nameLabel.text = organization.name
    }

    override func prepareForReuse() {
        badgeLabel.text = nil
        nameLabel.text = nil
        iconView.image = nil
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        badgeLabel.layer.borderColor = chooseColor(.Neutral_07).cgColor
        iconView.layer.borderColor = chooseColor(.Neutral_07).cgColor
    }
}
