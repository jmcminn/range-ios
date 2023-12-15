import SnapKit
import UIKit

/// Round button with an image that changes its shadow when pressed
class RoundShadowButton: UIControl {
    enum Variant {
        case darkBlurred, blue
    }

    private let variant: Variant
    private let image: UIImage
    private let selectedImage: UIImage?
    private let size: CGFloat
    private let imageTintColor: UIColor
    private var imageView: UIImageView!
    private var imageConfiguration: UIImage.Configuration {
        UIImage.SymbolConfiguration(pointSize: 19)
            .applying(UIImage.SymbolConfiguration(weight: .regular))
    }

    ///
    init(
        image: UIImage,
        selectedImage: UIImage? = nil,
        size: CGFloat = 48,
        imageTintColor: UIColor = .Neutral_04,
        variant: Variant = .darkBlurred
    ) {
        self.variant = variant
        self.image = image
        self.selectedImage = selectedImage
        self.size = size
        self.imageTintColor = imageTintColor
        super.init(frame: .zero)

        layer.cornerRadius = size / 2.0
        layer.borderWidth = 1

        if variant == .darkBlurred {
            backgroundColor = .clear
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
            backgroundColor = .Primary_Blue_04
            layer.borderColor = UIColor(white: 0, alpha: 0.1).cgColor
        }

        setShadowWithFigmaValues(x: 0, y: 6, blur: 10, opacity: 0.1)
        isHighlighted = false

        imageView = UIImageView(
            image: image.withRenderingMode(.alwaysTemplate).withConfiguration(imageConfiguration)
        )
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        onIsSelectedChange()

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
        guard variant == .darkBlurred else { return }
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
            if variant == .blue {
                backgroundColor = isHighlighted ? .Primary_Blue_04._highlightColor : .Primary_Blue_04
            }
        }
    }

    /// Update the image color when selected
    override var isSelected: Bool { didSet { onIsSelectedChange() } }

    /// Update UI when isSelected state changes
    private func onIsSelectedChange() {
        imageView.tintColor = isSelected ? .Primary_Blue_04 : imageTintColor
        // if selected image provided
        if let selectedImage = selectedImage {
            imageView.image = (isSelected ? selectedImage : image)
                .withRenderingMode(.alwaysTemplate)
                .withConfiguration(imageConfiguration)
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: size, height: size)
    }
}
