import Foundation
import UIKit

class OptionSelectorCollectionViewCell: UICollectionViewCell {
    private let roundedBackgroundView = UIView()
    private let label = UILabel()

    static var textToBorderHorizontalPadding = 10.0
    static var textToBorderVerticalPadding = 10.0
    // inset between the view frame and the content frame (on all sides) - to make the tap area bigger
    static var cellContentInset = 4.0

    override init(frame _: CGRect) {
        super.init(frame: .zero)

        roundedBackgroundView.layer.borderWidth = 1
        contentView.addSubview(roundedBackgroundView)
        roundedBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(OptionSelectorCollectionViewCell.cellContentInset)
        }

        contentView.addSubview(label)
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(OptionSelectorCollectionViewCell.cellContentInset)
        }
    }

    func setOption(_ name: String, selected: Bool) {
        roundedBackgroundView.layer.borderColor = selected
            ? UIColor.Primary_Blue_04.cgColor
            : UIColor.dynamic(.Neutral_07).cgColor
        roundedBackgroundView.backgroundColor = selected ? .Primary_Blue_01 : .dynamic(.Neutral_10)
        label.text = name
        label.textColor = selected ? .dynamic(.Neutral_04) : .dynamic(.Neutral_05)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        roundedBackgroundView.layer.cornerRadius = frame.height / 2.0 - OptionSelectorCollectionViewCell
            .cellContentInset
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setOption("", selected: false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
