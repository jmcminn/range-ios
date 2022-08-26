import Foundation
import UIKit

/// A view of a pin with a small rounded image inside
/// The view is sized so the pin tip is in the middle of the view (helps with scaling the pin size down to 0, so it scales towards the tip)
class PhotoPin: PassthroughView {
    let _intrinsicContentSize: CGSize
    init(image: UIImage) {
        let pinImage = UIImage(named: "photopin")!
        _intrinsicContentSize = CGSize(
            width: pinImage.size.width,
            height: (pinImage.size.height - pinImage.alignmentRectInsets.bottom) * 2
        )
        super.init(frame: .zero)
        let pinView = UIImageView(image: pinImage)

        let imageInset = 2.5
        let imageSize = pinView.frame.width - 2 * imageInset
        let imageView = UIImageView(image: image.imageResized(toFill: imageSize))
        imageView.contentMode = .scaleAspectFill

        imageView.frame = CGRect(x: imageInset, y: imageInset, width: imageSize, height: imageSize)
        imageView.layer.cornerRadius = imageSize / 2.0
        imageView.layer.borderWidth = 1.3
        imageView.layer.borderColor = UIColor.Secondary_03.cgColor
        imageView.clipsToBounds = true
        pinView.addSubview(imageView)

        addSubview(pinView)
    }

    override var intrinsicContentSize: CGSize {
        _intrinsicContentSize
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
