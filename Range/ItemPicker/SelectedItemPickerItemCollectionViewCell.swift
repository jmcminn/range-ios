import Foundation
import UIKit

class SelectedItemPickerItemCollectionViewCell: UICollectionViewCell {
    static let leadingInset = 10.0
    static let trailingLabelInset = 30.0
    static let imageToLabelOffset = 5.0

    let imageView = UIImageView()
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

        let font = UIFont._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)

        imageView.tintColor = .dynamic(.Neutral_04)
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().inset(SelectedItemPickerItemCollectionViewCell.leadingInset)
        }

        contentView.addSubview(label)
        label.font = font
        label.textColor = .dynamic(.Neutral_04)
        label.adjustsFontForContentSizeCategory = true
        label.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().inset(SelectedItemPickerItemCollectionViewCell.leadingInset)
            make.trailing.equalToSuperview().inset(SelectedItemPickerItemCollectionViewCell.trailingLabelInset)
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

    func setItem(_ item: ItemPickerItem, imageSystemName: String?) {
        label.text = item.name
        if let imageSystemName, let image = UIImage(
            systemName: imageSystemName,
            withConfiguration: UIImage.SymbolConfiguration(font:
                ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold))
        ) {
            imageView.image = image
            imageView.isHidden = false
            label.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalTo(imageView.snp.trailing)
                    .offset(SelectedItemPickerItemCollectionViewCell.imageToLabelOffset)
                make.trailing.equalToSuperview().inset(SelectedItemPickerItemCollectionViewCell.trailingLabelInset)
            }
        } else {
            imageView.image = nil
            imageView.isHidden = true
            label.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalToSuperview().inset(SelectedItemPickerItemCollectionViewCell.leadingInset)
                make.trailing.equalToSuperview().inset(SelectedItemPickerItemCollectionViewCell.trailingLabelInset)
            }
        }
    }

    override func prepareForReuse() {
        label.text = nil
        imageView.image = nil
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
