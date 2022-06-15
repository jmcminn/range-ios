import Foundation
import UIKit

class TagCollectionViewCell: UICollectionViewCell {
    static let leadingLabelInset = 10.0
    static let trailingLabelInset = 30.0
    let label = UILabel()

    var onDeselect: (() -> Void)?

    override init(frame _: CGRect) {
        super.init(frame: .zero)

        let backgroundView = UIView()
        backgroundView.layer.borderWidth = 1
        backgroundView.layer.cornerRadius = 16
        backgroundView.layer.borderColor = UIColor.Primary_Blue_04.cgColor
        backgroundView.backgroundColor = .Primary_Blue_02
        contentView.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0))
        }

        contentView.addSubview(label)
        label.font = UIFont.preferredFont(forTextStyle: .caption2)
        label.textColor = .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
        label.snp.makeConstraints { make in
            make.centerY.equalToSuperview().offset(-8)
            make.leading.equalToSuperview().inset(TagCollectionViewCell.leadingLabelInset)
            make.trailing.equalToSuperview().inset(TagCollectionViewCell.trailingLabelInset)
        }

        var unselectButtonConfig = UIButton.Configuration.plain()
        // adjust content insets so the 'x' is place properly in the tag cell but also has
        // as biggest area as possible (but not symmetric to the center of x)
        unselectButtonConfig.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 19, trailing: 6)
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

    unowned var tagViewModel: TagViewModel? {
        didSet {
            if let tagViewModel = tagViewModel {
                label.text = tagViewModel.name
            } else {
                label.text = ""
            }
        }
    }

    override func prepareForReuse() {
        tagViewModel = nil
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
