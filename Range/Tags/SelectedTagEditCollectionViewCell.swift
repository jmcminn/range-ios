import Foundation
import UIKit

class SelectedTagEditCollectionViewCell: UICollectionViewCell {
    static let labelText = String(localized: "Edit")
    static let tagImageName = "tag"
    static let imageToLabelDistance: CGFloat = 3

    private let tagBackgroundView = UIView()
    private let label = UILabel()

    /// insets for tap area, to make the tap area larger provide negative values
    var tapAreaInsets: UIEdgeInsets = .zero

    override func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        let newArea = CGRect(
            x: bounds.origin.x + tapAreaInsets.left,
            y: bounds.origin.y + tapAreaInsets.top,
            width: bounds.size.width - tapAreaInsets.left - tapAreaInsets.right,
            height: bounds.size.height - tapAreaInsets.top - tapAreaInsets.bottom
        )
        return newArea.contains(point)
    }

    override init(frame _: CGRect) {
        super.init(frame: .zero)

        tagBackgroundView.layer.borderWidth = 1
        tagBackgroundView.layer.cornerRadius = 16
        tagBackgroundView.backgroundColor = .dynamic(.Neutral_10)
        contentView.addSubview(tagBackgroundView)
        tagBackgroundView.snp.makeConstraints { make in
            // the visible cell is lower than touchable area
            make.leading.trailing.centerY.equalToSuperview()
            make.height.equalTo(32)
        }

        let font = UIFont._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)

        let tagImageView = UIImageView(image: UIImage(
            systemName: TagAddCollectionViewCell.tagImageName,
            withConfiguration: UIImage.SymbolConfiguration(font: font)
        ))
        tagImageView.tintColor = .dynamic(.Neutral_05)
        contentView.addSubview(tagImageView)
        tagImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().inset(TagCollectionViewCell.leadingLabelInset)
        }

        contentView.addSubview(label)
        label.text = SelectedTagEditCollectionViewCell.labelText
        label.textAlignment = .center
        label.font = font
        label.textColor = .dynamic(.Neutral_05)
        label.adjustsFontForContentSizeCategory = true
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
        tagBackgroundView.layer.borderColor = UIColor.dynamic(.Neutral_07).cgColor
    }
}
