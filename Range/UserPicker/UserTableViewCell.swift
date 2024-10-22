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

    let avatarView = AvatarView()
    let firstLineScrollView = UIScrollView()
    let firstLineStackView = UIStackView()
    let nameLabel = UILabel()
    let emailLabel = UILabel()
    let selectedIconView = UIImageView(image: UIImage(named: "checkmark_checked"))
    private let multiselect: Bool

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        multiselect = reuseIdentifier == Variant.identifier(forMultiselect: true)
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clear // bg is covered by addBackgroundWithBorder in the view controller

        setupViews()
        [avatarView, firstLineScrollView, emailLabel, selectedIconView].forEach(contentView.addSubview)

        avatarView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview().offset(14)
            make.bottom.lessThanOrEqualToSuperview().offset(-14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
            make.leading.equalTo(contentView.snp.leadingMargin).offset(multiselect ? 44 : 12)
        }
        firstLineScrollView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualToSuperview().offset(11)
            make.bottom.equalTo(contentView.snp.centerY).offset(2)
            make.leading.equalTo(contentView.snp.leadingMargin).offset(multiselect ? 84 : 52)
            make.trailing.equalTo(contentView.snp.trailingMargin)
        }
        emailLabel.snp.makeConstraints { make in
            make.top.equalTo(firstLineStackView.snp.bottom)
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
        // the firstLineScrollView has user interaction disabled so the cell selection works
        // but we still want it's pan gesture to work
        contentView.addGestureRecognizer(firstLineScrollView.panGestureRecognizer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        // no user interaction - we want taps recognized by the table view cell
        firstLineScrollView.isUserInteractionEnabled = false
        firstLineScrollView.showsHorizontalScrollIndicator = false
        firstLineScrollView.addSubview(firstLineStackView)
        firstLineStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(firstLineScrollView)
        }
        firstLineStackView.isUserInteractionEnabled = false

        firstLineStackView.axis = .horizontal
        firstLineStackView.alignment = .center
        firstLineStackView.spacing = 8

        nameLabel.textColor = .dynamic(.Neutral_04)
        nameLabel.font = .preferredFont(forTextStyle: .body)

        emailLabel.textColor = .dynamic(.Neutral_05)
        emailLabel.font = ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
    }

    func setUser(_ user: UserViewModel, avatarImage: UIImage?, showRole: Bool, showPending: Bool) {
        avatarView.setAvatar(avatarImage, initials: user.initials)
        nameLabel.attributedText = NSAttributedString(
            string: user.name,
            attributes: [.strikethroughStyle: user.strikethroughStyle]
        )
        if user.suspended {
            // don't show email if user is suspended
            firstLineScrollView.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalTo(contentView.snp.leadingMargin).offset(multiselect ? 84 : 52)
                make.trailing.equalTo(contentView.snp.trailingMargin)
            }
            emailLabel.isHidden = true
            emailLabel.text = nil
        } else {
            firstLineScrollView.snp.remakeConstraints { make in
                make.top.greaterThanOrEqualToSuperview().offset(11)
                make.bottom.equalTo(contentView.snp.centerY).offset(2)
                make.leading.equalTo(contentView.snp.leadingMargin).offset(multiselect ? 84 : 52)
                make.trailing.equalTo(contentView.snp.trailingMargin)
            }
            emailLabel.isHidden = false
            emailLabel.text = user.email
        }
        if showPending, user.pending {
            firstLineStackView.addArrangedSubview(PillView(
                iconName: nil, text: "Pending", verticalPadding: 0, backgroundColor: .Primary_Blue_01
            ))
        }
        firstLineStackView.addArrangedSubview(nameLabel)
        if showRole {
            firstLineStackView.addArrangedSubview(PillView(
                iconName: nil, text: user.role.rawValue, verticalPadding: 0, backgroundColor: .dynamic(.Neutral_10)
            ))
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
        avatarView.setAvatar(nil, initials: nil)
        firstLineStackView.arrangedSubviews.forEach {
            firstLineStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        firstLineScrollView.setContentOffset(.zero, animated: false)
        nameLabel.attributedText = nil
        emailLabel.text = nil
        selectedIconView.isHidden = true
    }
}
