import Foundation
import UIKit

class TagCollectionViewCell: UICollectionViewCell {
    static let minLabelWidth = 20.0
    static let leadingLabelInset = 10.0
    static let trailingLabelInset = 10.0
    private let label = UILabel()

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
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)).priority(.high)
        }

        contentView.addSubview(label)
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .caption2)
        label.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
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
