import UIKit

/// Simple "toast" view that displays given text
class ToastView: UIView {
    init(text: String, backgroundColor: UIColor, borderColor: UIColor? = nil) {
        super.init(frame: .zero)

        self.backgroundColor = backgroundColor
        setShadowWithFigmaValues(x: 0, y: 6, blur: 10, opacity: 0.1)
        layer.cornerRadius = 10
        if let borderColor = borderColor {
            layer.borderWidth = 1
            layer.borderColor = borderColor.cgColor
        }

        let textLabel = UILabel()
        textLabel.font = ._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold)
        textLabel.text = text
        textLabel.textColor = UIColor.Neutral_01
        textLabel.numberOfLines = 0
        addSubview(textLabel)

        textLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
