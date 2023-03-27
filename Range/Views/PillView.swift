import Foundation
import UIKit

/// A pill view displaying an icon and text in a rounded box
class PillView: UIView {
    enum Style {
        case `default`
        case red // red font
        case tag // render similar to tags
        case disabled

        var borderColor: UIColor {
            switch self {
            case .default, .disabled:
                return .dynamicColor(light: .Neutral_04, dark: .Neutral_07)
            case .red: return .Red_03
            case .tag: return .Primary_Blue_04
            }
        }

        var tintColor: UIColor {
            switch self {
            case .default, .tag: return .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
            case .disabled: return .dynamicColor(light: .Neutral_06, dark: .Neutral_05)
            case .red: return .Red_03
            }
        }
    }

    private var font: UIFont {
        ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
    }

    private let style: Style
    private let borderView = UIView()
    private let iconView = UIImageView()
    private let label = UILabel()

    init(
        iconName: String,
        text: String,
        verticalPadding: Double = 8.0,
        backgroundColor: UIColor = .dynamic(.Neutral_09),
        style: Style = .default
    ) {
        self.style = style
        super.init(frame: .zero)

        borderView.layer.borderWidth = 1
        borderView.backgroundColor = backgroundColor

        iconView.image = UIImage(systemName: iconName, withConfiguration: UIImage.SymbolConfiguration(font: font))
        iconView.tintColor = style.tintColor

        label.text = text
        label.font = font
        label.adjustsFontForContentSizeCategory = true
        label.textColor = style.tintColor

        updateColors()

        addSubview(borderView)
        borderView.addSubview(iconView)
        borderView.addSubview(label)
        borderView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(verticalPadding)
            make.leading.trailing.equalToSuperview()
        }
        iconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().inset(8)
        }
        label.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(6)
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
        borderView.layer.borderColor = style.borderColor.cgColor
    }
}
