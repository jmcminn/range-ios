import SnapKit
import UIKit

/// Round button with an image that changes its shadow when pressed
class RoundShadowButton: UIControl {
    private let size: CGFloat

    ///
    init(image: UIImage, size: CGFloat = 48) {
        self.size = size
        super.init(frame: .zero)

        backgroundColor = .clear
        layer.cornerRadius = size / 2.0
        layer.borderWidth = 1

        let blurEffect = UIBlurEffect(style: .dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.isUserInteractionEnabled = false
        blurEffectView.layer.cornerRadius = layer.cornerRadius
        blurEffectView.clipsToBounds = true
        addSubview(blurEffectView)
        blurEffectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        setShadowWithFigmaValues(x: 0, y: 6, blur: 10, opacity: 0.1)
        isHighlighted = false

        let imageConfig = UIImage.SymbolConfiguration(pointSize: 19)
            .applying(UIImage.SymbolConfiguration(weight: .regular))
        let imageView = UIImageView(image: image.withRenderingMode(.alwaysTemplate).withConfiguration(imageConfig))
        imageView.tintColor = .Neutral_04
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
        if traitCollection.userInterfaceStyle == .dark {
            // make it white in dark mode "so it doesn't get lost in the grid background"
            layer.borderColor = UIColor(white: 1, alpha: 0.2).cgColor
        } else {
            layer.borderColor = UIColor(white: 0, alpha: 0.1).cgColor
        }
    }

    /// Update the shadow opacity when the button is pressed.
    override var isHighlighted: Bool {
        didSet {
            layer.shadowOpacity = isHighlighted ? 0.4 : 0.1
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: size, height: size)
    }
}
