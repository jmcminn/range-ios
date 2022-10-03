import Foundation
import UIKit

class TagAddCollectionViewCell: UICollectionViewCell {
    static let labelText = String(localized: "Add")
    static let imageToLabelDistance: CGFloat = 3
    static let tagImage = UIImage(
        systemName: "tag",
        withConfiguration: UIImage.SymbolConfiguration(textStyle: .caption1)
    )
    private let tagBackgroundView = UIView()
    private let label = UILabel()

    override init(frame _: CGRect) {
        super.init(frame: .zero)

        tagBackgroundView.layer.borderWidth = 1
        tagBackgroundView.layer.cornerRadius = 16
        tagBackgroundView.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_08)
        contentView.addSubview(tagBackgroundView)
        tagBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)).priority(.high)
        }

        let tagImageView = UIImageView(image: TagAddCollectionViewCell.tagImage)
        tagImageView.tintColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_05)
        contentView.addSubview(tagImageView)
        tagImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().inset(TagCollectionViewCell.leadingLabelInset)
        }

        contentView.addSubview(label)
        label.text = TagAddCollectionViewCell.labelText
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.textColor = .dynamicColor(light: .Neutral_06, dark: .Neutral_05)
        label.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(TagCollectionViewCell.minLabelWidth)
            make.leading.equalTo(tagImageView.snp.trailing).offset(TagAddCollectionViewCell.imageToLabelDistance)
            make.trailing.equalToSuperview().inset(TagCollectionViewCell.trailingLabelInset).priority(.high)
        }

        updateColors()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        updateColors()
    }

    /// Update colors that doesn't automatically adapt to appearance change
    private func updateColors() {
        tagBackgroundView.layer.borderColor = UIColor.dynamicColor(light: .Neutral_04, dark: .Neutral_07).cgColor
    }
}
