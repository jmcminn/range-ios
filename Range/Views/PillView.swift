import Foundation
import UIKit

/// A pill view displaying an icon and text in a rounded box
class PillView: UIView {
    enum Style {
        case `default`
        case red // red font
        case tag // render similar to tags
        case flat // white text on provided bg color, no border
        case disabled

        var borderColor: UIColor? {
            switch self {
            case .default, .disabled: return .dynamic(.Neutral_07)
            case .red: return .Red_03
            case .tag: return .Primary_Blue_04
            case .flat: return nil
            }
        }

        var tintColor: UIColor {
            switch self {
            case .default, .tag: return .dynamic(.Neutral_04)
            case .disabled: return .dynamic(.Neutral_05)
            case .red: return .Red_03
            case .flat: return .white
            }
        }
    }

    private var font: UIFont {
        ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
    }

    private let style: Style
    private let borderView = UIView()
    private let iconView = UIImageView()
    private(set) var label = UILabel()

    init(
        iconName: String?,
        text: String,
        verticalPadding: Double = 8.0,
        backgroundColor: UIColor = .dynamic(.Neutral_09),
        style: Style = .default,
        textAttributes: [NSAttributedString.Key: Any]? = nil
    ) {
        self.style = style
        super.init(frame: .zero)

        if style.borderColor != nil {
            borderView.layer.borderWidth = 1
        }
        borderView.backgroundColor = backgroundColor

        if let iconName {
            iconView.image = UIImage(systemName: iconName, withConfiguration: UIImage.SymbolConfiguration(font: font))
            iconView.tintColor = style.tintColor
        }

        if let textAttributes = textAttributes {
            label.attributedText = NSAttributedString(string: text, attributes: textAttributes)
        } else {
            label.text = text
        }
        label.font = font
        label.adjustsFontForContentSizeCategory = true
        label.textColor = style.tintColor

        updateColors()

        addSubview(borderView)
        if iconName != nil {
            borderView.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalToSuperview().inset(8)
            }
        }
        borderView.addSubview(label)
        borderView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(verticalPadding)
            make.leading.trailing.equalToSuperview()
        }

        label.snp.makeConstraints { make in
            if iconName != nil {
                make.leading.equalTo(iconView.snp.trailing).offset(6)
            } else {
                make.leading.equalToSuperview().inset(8)
            }
            make.trailing.equalToSuperview().inset(8)
            make.top.bottom.equalToSuperview().inset(4)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        borderView.layer.cornerRadius = borderView.frame.height / 2
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    private func updateColors() {
        if let borderColor = style.borderColor {
            borderView.layer.borderColor = borderColor.cgColor
        }
    }
}
