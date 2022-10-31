import SnapKit
import UIKit

/// Round button with an image that changes its shadow when pressed
class RoundShadowButton: UIControl {
    private let style: Style
    enum Style {
        case black, blue
    }

    init(image: UIImage, style: Style = .black, size: CGFloat = 48) {
        self.style = style
        super.init(frame: .zero)

        backgroundColor = style == .black
            ? .dynamicColor(light: .Neutral_02, dark: .Neutral_09)
            : .Primary_Blue_04
        layer.cornerRadius = size / 2.0
        layer.borderWidth = 1

        setShadowWithFigmaValues(x: 0, y: 6, blur: 10, opacity: 0.1)
        isHighlighted = false

        snp.makeConstraints { make in
            make.width.height.equalTo(size).priority(.required)
        }

        let imageConfig = UIImage.SymbolConfiguration(textStyle: .subheadline)
            .applying(UIImage.SymbolConfiguration(weight: style == .black ? .regular : .bold))
        let imageView = UIImageView(image: image.withConfiguration(imageConfig))
        imageView.tintColor = style == .black
            ? .dynamicColor(light: .Neutral_07, dark: .Neutral_04)
            : .Neutral_01
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
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

    /// Update colors that do not automatically adjust when appearance changes
    private func updateColors() {
        layer.borderColor = style == .black
            ? UIColor.dynamicColor(light: .Neutral_04, dark: .Neutral_07).cgColor
            : UIColor.Primary_Blue_06.cgColor
    }

    /// Update the shadow opacity when the button is pressed.
    override var isHighlighted: Bool {
        didSet {
            layer.shadowOpacity = isHighlighted ? 0.4 : 0.1
        }
    }
}
