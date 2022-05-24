import SnapKit
import UIKit

/// Round button with an image that changes its shadow when pressed
class RoundButton: UIControl {
    init(image: UIImage, size: CGFloat = 48) {
        super.init(frame: .zero)

        backgroundColor = .Neutral_10
        layer.cornerRadius = size / 2.0

        addDropshadowMd02()
        isHighlighted = false

        snp.makeConstraints { make in
            make.width.equalTo(size).priority(.required)
            make.height.equalTo(size).priority(.required)
        }

        let imageConfig = UIImage.SymbolConfiguration(textStyle: .subheadline)
            .applying(UIImage.SymbolConfiguration(weight: .bold))
        let imageView = UIImageView(image: image.withConfiguration(imageConfig))
        imageView.tintColor = .Neutral_01
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
            layer.shadowOpacity = isHighlighted ? 0.4 : 0.2
        }
    }
}
