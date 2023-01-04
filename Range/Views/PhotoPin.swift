import Foundation
import UIKit

/// A view of a pin with a small rounded image inside
/// The view is sized so the pin tip is in the middle of the view (helps with scaling the pin size down to 0, so it scales towards the tip)
class PhotoPin: PassthroughView {
    let _intrinsicContentSize: CGSize
    init(image: UIImage) {
        let pinView: UIView
        // construct pin with "0" photos - the 0 will be covered by `image`
        let pinDisplayOptions = PinDisplayOptions.regularPinDisplayOptionsProvider(
            collaboration: Collaboration(placeholderId: ""),
            selected: true,
            anythingSelected: false
        )
        if let pinImage = pinDisplayOptions.pinImage.image {
            pinView = UIImageView(image: pinImage)
            _intrinsicContentSize = CGSize(
                width: pinImage.size.width,
                height: (pinImage.size.height + pinDisplayOptions.offsetY) * 2
            )
        } else {
            // if we couldn't construct the PinImage.image, this shouldn't happen
            pinView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 40, height: 60)))
            _intrinsicContentSize = CGSize(width: pinView.frame.width, height: pinView.frame.height)
        }
        super.init(frame: .zero)

        let imageInset = 10.0
        let imageSize = pinView.frame.width - 2 * imageInset
        let imageView = UIImageView(image: image.imageResized(toFill: imageSize))
        imageView.contentMode = .scaleAspectFill

        imageView.frame = CGRect(x: imageInset, y: imageInset + 4.5, width: imageSize, height: imageSize)
        imageView.layer.cornerRadius = imageSize / 2.0
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.Pink_04.cgColor
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
