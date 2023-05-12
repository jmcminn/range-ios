import UIKit

/// Simple "toast" view that displays given text with optional icon
class ToastView: UIView {
    /// when blurring background the backgroundColor is irrelevant
    init(
        iconName: String? = nil,
        text: String,
        backgroundColor: UIColor,
        borderColor: UIColor? = nil,
        blurBackground: Bool = false
    ) {
        super.init(frame: .zero)

        layer.cornerRadius = 10

        if blurBackground {
            let blurEffect = UIBlurEffect(style: .dark)
            let blurEffectView = UIVisualEffectView(effect: blurEffect)
            blurEffectView.isUserInteractionEnabled = false
            blurEffectView.layer.cornerRadius = layer.cornerRadius
            blurEffectView.clipsToBounds = true
            addSubview(blurEffectView)
            blurEffectView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        } else {
            self.backgroundColor = backgroundColor
        }
        setShadowWithFigmaValues(x: 0, y: 6, blur: 10, opacity: 0.1)
        if let borderColor = borderColor {
            layer.borderWidth = 1
            layer.borderColor = borderColor.cgColor
        }

        let font = UIFont._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold)

        let textLabel = UILabel()
        textLabel.font = font
        textLabel.text = text
        textLabel.textColor = .Neutral_01
        textLabel.numberOfLines = 0
        textLabel.adjustsFontForContentSizeCategory = true
        addSubview(textLabel)

        if let iconName = iconName, let image = UIImage(
            systemName: iconName, withConfiguration: UIImage.SymbolConfiguration(font: font)
        ) {
            let iconView = UIImageView(image: image)
            iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
            iconView.tintColor = .Neutral_01
            addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.leading.equalToSuperview().inset(10)
                make.centerY.equalToSuperview()
            }
            textLabel.snp.makeConstraints { make in
                make.leading.equalTo(iconView.snp.trailing).offset(6)
                make.top.bottom.trailing.equalToSuperview().inset(10)
            }
        } else {
            textLabel.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
