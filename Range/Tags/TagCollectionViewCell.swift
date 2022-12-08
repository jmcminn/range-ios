import Foundation
import UIKit

class TagCollectionViewCell: UICollectionViewCell {
    static let minLabelWidth = 20.0
    static let leadingLabelInset = 10.0
    static let trailingLabelInset = 10.0
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

    /// the name of the tag
    var tagName: String? {
        didSet {
            label.text = tagName
        }
    }

    override init(frame _: CGRect) {
        super.init(frame: .zero)

        let backgroundView = UIView()
        backgroundView.layer.borderWidth = 1
        backgroundView.layer.cornerRadius = 16
        backgroundView.layer.borderColor = UIColor.Primary_Blue_04.cgColor
        backgroundView.backgroundColor = .Primary_Blue_01
        contentView.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview().priority(.high)
        }

        contentView.addSubview(label)
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .caption2)
        label.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        label.adjustsFontForContentSizeCategory = true
        label.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(TagCollectionViewCell.minLabelWidth)
            make.leading.equalToSuperview().inset(TagCollectionViewCell.leadingLabelInset)
            make.trailing.equalToSuperview().inset(TagCollectionViewCell.trailingLabelInset).priority(.high)
        }
    }

    override func prepareForReuse() {
        tagName = nil
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
