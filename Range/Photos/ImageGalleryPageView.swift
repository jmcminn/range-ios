import Foundation
import UIKit

/// View displayed in the ImageGalleryViewController for 1 image.
class ImageGalleryPageView: UIView {
    let imageView = UIImageView()
    /// top/bottom insets for image view, so the side pages in the gallery are lower than the center one.
    /// left/right inset values doesn't matter, but if any is non zero, the image view will be pushed towards the other edge, for example
    /// if left inset is 1 and right is 0 the imageView will be aligned to the right
    var imageInset: UIEdgeInsets = .zero
    /// image aspect ratio is required for sizing the imageView. initially it might be set to some sample value, later updated to
    /// real value when the image is loaded
    var imageHeight2Width: Double? {
        didSet {
            if imageHeight2Width != oldValue {
                setNeedsLayout()
                layoutIfNeeded()
            }
        }
    }

    init() {
        super.init(frame: .zero)

        imageView.layer.cornerRadius = 13
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        imageView.kf.indicatorType = .activity
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // default imageHeight2Width to 4/3, it should always be set, not necessarily with the final value
        imageView.frame = imageViewFrame(
            forImageHeight2Width: imageHeight2Width ?? 4.0 / 3.0, imageInset: imageInset
        )
    }

    /// calculate image frame so it's aspect ratio is preserved and take all insets into account
    func imageViewFrame(forImageHeight2Width height2Width: Double, imageInset: UIEdgeInsets = .zero) -> CGRect {
        // always add 8 points of horizontal margin, it gives spacing between pages
        let horizontalMargin = 8.0

        // layout image so it's aspect ratio is preserved and take all insets into account
        let availableWidth = max(1, bounds.width - 2 * horizontalMargin)
        let availableHeight = bounds.height
        let availableHeight2Width = availableHeight / availableWidth
        let imageSize: CGSize
        if availableHeight2Width >= height2Width {
            // too high
            imageSize = CGSize(width: availableWidth, height: availableWidth * height2Width)
        } else {
            // too wide
            imageSize = CGSize(width: availableHeight / height2Width, height: availableHeight)
        }

        // now apply the imageInsets
        let insetImageHeight = max(0, imageSize.height - imageInset.top - imageInset.bottom)
        let insetImageWidth = insetImageHeight / height2Width

        // left/right inset depending on the imageInset
        let insetImageX = imageInset.right > 0
            ? horizontalMargin
            : (imageInset.left > 0
                ? bounds.width - horizontalMargin - insetImageWidth
                : (bounds.width - insetImageWidth) / 2.0)
        return CGRect(
            x: insetImageX,
            y: (bounds.height - insetImageHeight) / 2.0,
            width: insetImageWidth,
            height: insetImageHeight
        )
    }
}
