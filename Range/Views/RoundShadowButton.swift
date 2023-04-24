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
        layer.borderColor = UIColor(white: 0, alpha: 0.1).cgColor

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
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
