import Foundation
import UIKit

/// A view of a pin with a small rounded image inside
/// The view is sized so the pin tip is in the middle of the view (helps with scaling the pin size down to 0, so it scales towards the tip)
class PhotoPin: PassthroughView {
    let _intrinsicContentSize: CGSize
    let taskPinColor: UIColor
    let pinView: UIImageView
    let imageView: UIImageView
    var pinType: PinType = .photo {
        didSet {
            onPinTypeUpdated()
        }
    }

    ///
    /// - Parameters:
    ///   - image:   displayed for photo pins
    ///   - taskPinColor: color to use for task pins (should be taken from initial status)
    init(image: UIImage, taskPinColor: UIColor) {
        self.taskPinColor = taskPinColor
        // construct pin with "0" photos - the 0 will be covered by `image`
        if let pinImage = PinImage.pinPhoto(count: 0).image {
            pinView = UIImageView(image: pinImage)
            _intrinsicContentSize = CGSize(
                width: pinImage.size.width,
                height: (pinImage.size.height + PinDisplayOptions.pinYOffset) * 2
            )
        } else {
            // if we couldn't construct the PinImage.image, this shouldn't happen
            pinView = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: 40, height: 60)))
            _intrinsicContentSize = CGSize(width: pinView.frame.width, height: pinView.frame.height)
        }
        let imageInset = 10.0
        let imageSize = pinView.frame.width - 2 * imageInset
        imageView = UIImageView(image: image.imageResized(toFill: imageSize))

        super.init(frame: .zero)

        imageView.contentMode = .scaleAspectFill
        imageView.frame = CGRect(x: imageInset, y: imageInset + 4.5, width: imageSize, height: imageSize)
        imageView.layer.cornerRadius = imageSize / 2.0
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.Pink_04.cgColor
        imageView.clipsToBounds = true
        pinView.addSubview(imageView)

        addSubview(pinView)
    }

    private func onPinTypeUpdated() {
        imageView.isHidden = pinType != .photo

        let pinImage: PinImage
        switch pinType {
        case .photo: pinImage = .pinPhoto(count: 0)
        case .task: pinImage = .pinTask(color: taskPinColor)
        case .photoOrTask: pinImage = .copyPin
        }
        pinView.image = pinImage.image
    }

    override var intrinsicContentSize: CGSize {
        _intrinsicContentSize
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupImageView() {}
}
