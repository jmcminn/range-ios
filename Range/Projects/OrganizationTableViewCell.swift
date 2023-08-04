import Foundation
import UIKit

class OrganizationTableViewCell: UITableViewCell {
    let badgeLabel = UILabel()
    let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in the view controller

        setupViews()
        [badgeLabel, nameLabel].forEach(contentView.addSubview)

        badgeLabel.snp.makeConstraints { make in
            make.width.height.equalTo(32)
            make.top.greaterThanOrEqualToSuperview().offset(13)
            make.bottom.lessThanOrEqualToSuperview().offset(-13)
            make.centerY.equalToSuperview()
            make.leading.equalTo(contentView.snp.leadingMargin).inset(16)
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
    }

    func setOrganization(_ organization: Organization, selected _: Bool) {
        badgeLabel.text = organization.name.prefix(1).uppercased()
        nameLabel.text = organization.name
    }

    override func prepareForReuse() {
        badgeLabel.text = nil
        nameLabel.text = nil
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        badgeLabel.layer.borderColor = chooseColor(.Neutral_07).cgColor
    }
}
