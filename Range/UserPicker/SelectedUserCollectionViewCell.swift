import Foundation
import UIKit

class SelectedUserCollectionViewCell: UICollectionViewCell {
    static let leadingLabelInset = 40.0
    static let trailingLabelInset = 30.0

    let avatarView = AvatarView()
    let label = UILabel()

    var onDeselect: (() -> Void)?

    override init(frame _: CGRect) {
        super.init(frame: .zero)

        let backgroundView = UIView()
        backgroundView.layer.borderWidth = 1
        backgroundView.layer.cornerRadius = 16
        backgroundView.layer.borderColor = UIColor.Primary_Blue_04.cgColor
        backgroundView.backgroundColor = .Primary_Blue_01
        contentView.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            // the visible cell is lower than touchable area
            make.leading.trailing.centerY.equalToSuperview()
            make.height.equalTo(32)
        }

        contentView.addSubview(avatarView)
        avatarView.snp.makeConstraints { make in
            make.centerY.leading.equalToSuperview()
            make.width.height.equalTo(32)
        }
        updateAvatarImage()

        contentView.addSubview(label)
        label.font = UIFont._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
        label.textColor = .dynamic(.Neutral_04)
        label.adjustsFontForContentSizeCategory = true
        label.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().inset(SelectedUserCollectionViewCell.leadingLabelInset)
            make.trailing.equalToSuperview().inset(SelectedUserCollectionViewCell.trailingLabelInset)
        }

        var unselectButtonConfig = UIButton.Configuration.plain()
        // adjust content insets so the 'x' is place properly in the tag cell but also has
        // as biggest area as possible (but not symmetric to the center of x)
        unselectButtonConfig.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 10, bottom: 9, trailing: 6)
        unselectButtonConfig.baseForegroundColor = .Primary_Blue_04

        let unselectButton = UIButton(
            configuration: unselectButtonConfig,
            primaryAction: UIAction(image: UIImage(named: "xmark_circle")?.withRenderingMode(.alwaysTemplate)) {
                [weak self] _ in self?.onDeselect?()
            }
        )

        contentView.addSubview(unselectButton)

        unselectButton.snp.makeConstraints { make in
            make.trailing.top.equalToSuperview()
        }
    }

    private var showUnassignedAvatar: Bool = false

    func setUser(_ user: UserViewModel, avatarImage: UIImage?) {
        label.attributedText = NSAttributedString(
            string: user.name,
            attributes: [.strikethroughStyle: user.strikethroughStyle]
        )
        showUnassignedAvatar = user.id == UserViewModel.unassignedUserId
        if !showUnassignedAvatar {
            avatarView.setAvatar(avatarImage, initials: user.initials)
        }
        updateAvatarImage()
    }

    private func updateAvatarImage() {
        if showUnassignedAvatar {
            // SF symbol is not used here as we need the one that is properly centered (and sf symbol
            // for person.crop.circle.fill.badge.xmark is not centered at the person center horizontally)
            let image = UIImage(named: "no_assignee")?
                .withTintColor(chooseColor(.Neutral_05),
                               renderingMode: .alwaysTemplate)
                .addCircleBackground(
                    bgSize: CGSize(width: 32, height: 32),
                    bgColor: chooseColor(.Neutral_10),
                    strokeColor: .Primary_Blue_04
                )
            avatarView.setAvatar(image, initials: nil)
            avatarView.layer.borderWidth = 0
        } else {
            avatarView.layer.borderColor = UIColor.Primary_Blue_04.cgColor
            avatarView.layer.borderWidth = 1
        }
    }

    override func prepareForReuse() {
        avatarView.setAvatar(nil, initials: nil)
        label.text = nil
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateAvatarImage()
    }
}
