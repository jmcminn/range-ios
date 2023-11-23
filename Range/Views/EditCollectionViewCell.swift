import Foundation
import UIKit

/// Collection view cell showing an Edit (or Add) text with an icon (all depending on the variant)
/// Used in tags and users selected collection views
class EditCollectionViewCell: UICollectionViewCell {
    /// The cell has multiple variants based on the reuseIdentifier
    enum Variant {
        case addTag, editTag, editUser, editCanvas

        var label: String {
            switch self {
            case .addTag: return String(localized: "Add")
            case .editTag: return String(localized: "Edit")
            case .editUser: return String(localized: "Edit")
            case .editCanvas: return String(localized: "Edit")
            }
        }

        var image: String {
            switch self {
            case .addTag: return "tag"
            case .editTag: return "tag"
            case .editUser: return "person"
            case .editCanvas: return "square.3.layers.3d"
            }
        }

//        init(fromIdentifier: String?) {
//            if let identifier = Variant.allCases.first(where: { $0.rawValue == fromIdentifier }) {
//                self = identifier
//            } else {
//                fatalError("Init EditCollectionViewCell from \(fromIdentifier) identifier not supported")
//            }
//        }
    }

//    static let labelText = String(localized: "Edit")
//    static let tagImageName = "tag"
    static let imageToLabelDistance: CGFloat = 3
    private let font = UIFont._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)

    let tagBackgroundView = UIView()
    private let imageView = UIImageView()
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

//        let tagImageView = UIImageView(image: UIImage(
//            systemName: "tag",
//            withConfiguration: UIImage.SymbolConfiguration(font: font)
//        ))
        imageView.tintColor = .dynamic(.Neutral_05)
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().inset(TagCollectionViewCell.leadingLabelInset)
        }

        contentView.addSubview(label)
        label.textAlignment = .center
        label.font = font
        label.textColor = .dynamic(.Neutral_05)
        label.adjustsFontForContentSizeCategory = true
        label.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(TagCollectionViewCell.minLabelWidth)
            make.leading.equalTo(imageView.snp.trailing).offset(EditCollectionViewCell.imageToLabelDistance)
            make.trailing.equalToSuperview().inset(TagCollectionViewCell.trailingLabelInset).priority(.high)
        }

        updateColors()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setVariant(_ variant: Variant) {
        imageView.image = UIImage(
            systemName: variant.image,
            withConfiguration: UIImage.SymbolConfiguration(font: font)
        )
        label.text = variant.label
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        updateColors()
    }

    /// Update colors that doesn't automatically adapt to appearance change
    private func updateColors() {
        tagBackgroundView.layer.borderColor = UIColor.dynamic(.Neutral_07).cgColor
    }

    override func prepareForReuse() {
        tagBackgroundView.backgroundColor = .dynamic(.Neutral_10)
    }
}
