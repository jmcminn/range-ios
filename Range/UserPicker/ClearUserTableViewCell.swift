import Foundation
import UIKit

class ClearUserTableViewCell: UITableViewCell {
    /// The cell has 2 variants based on the reuseIdentifier
    enum Variant: String {
        case single = "ClearUserCell"
        case multi = "UnassignedUserCell"

        static func identifier(forMultiselect: Bool) -> String {
            forMultiselect ? multi.rawValue : single.rawValue
        }
    }

    let avatarView = UIImageView()
    let nameLabel = UILabel()
    let selectedIconView = UIImageView(image: UIImage(named: "checkmark_checked"))
    private let multiselect: Bool

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        multiselect = reuseIdentifier == Variant.identifier(forMultiselect: true)
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in the view controller

        setupViews()
        [avatarView, nameLabel].forEach(contentView.addSubview)

        avatarView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
            make.leading.equalTo(contentView.snp.leadingMargin).offset(multiselect ? 44 : 12)
        }
        nameLabel.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview().offset(15)
            make.bottom.lessThanOrEqualToSuperview().offset(-15)
            make.leading.equalTo(contentView.snp.leadingMargin).offset(multiselect ? 84 : 52)
            make.trailing.equalTo(contentView.snp.trailingMargin).inset(16)
        }

        if multiselect {
            contentView.addSubview(selectedIconView)
            selectedIconView.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalTo(contentView.snp.leadingMargin).inset(12)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        updateAvatarImage()
    }

    private func setupViews() {
        avatarView.layer.cornerRadius = 16
        avatarView.backgroundColor = .dynamic(.Neutral_07)
        updateAvatarImage()

        nameLabel.textColor = .dynamic(.Neutral_04)
        nameLabel.font = .preferredFont(forTextStyle: .body)
        nameLabel.text = multiselect ? String(localized: "Unassigned Tasks") : String(localized: "No Assignee")
    }

    private func updateAvatarImage() {
        // SF symbol is not used here as we need the one that is properly centered (and sf symbol
        // for person.crop.circle.fill.badge.xmark is not centered at the person center horizontally)
        avatarView.image = UIImage(named: "no_assignee")?
            .withTintColor(chooseColor(.Neutral_05),
                           renderingMode: .alwaysTemplate)
            .addCircleBackground(
                bgSize: CGSize(width: 32, height: 32),
                bgColor: chooseColor(.Neutral_10),
                strokeColor: chooseColor(.Neutral_07)
            )
    }

    func setUser(_ user: UserViewModel) {
        if multiselect {
            selectedIconView.isHidden = false
            selectedIconView.image = user.selected
                ? UIImage(named: "checkmark_checked")
                : UIImage().addCircleBackground(bgSize: CGSize(width: 20, height: 20),
                                                bgColor: .dynamic(.Neutral_10),
                                                strokeColor: .dynamic(.Neutral_07))
        } else {
            selectedIconView.isHidden = true
        }
    }
}
