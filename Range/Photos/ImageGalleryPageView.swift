import Foundation
import UIKit

/// View displayed in the ImageGalleryViewController for 1 image.
class ImageGalleryPageView: UIView {
    let onPageTap: (() -> Void)?
    let onPhotoRemove: (() -> Void)?
    let onAnnotationsTap: (() -> Void)?
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

    var removeButton: RoundShadowButton?
    var annotationsButton: RoundShadowButton?

    init(onPageTap: (() -> Void)?, onAnnotationsTap: (() -> Void)?, onPhotoRemove: (() -> Void)? = nil) {
        self.onPageTap = onPageTap
        self.onPhotoRemove = onPhotoRemove
        self.onAnnotationsTap = onAnnotationsTap
        super.init(frame: .zero)

        imageView.layer.cornerRadius = 13
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.kf.indicatorType = .custom(indicator: ImageLoadingIndicator())

        addSubview(imageView)

        if onPageTap != nil {
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(pageTapped))
            tapRecognizer.delegate = self
            addGestureRecognizer(tapRecognizer)
        }
        if onPhotoRemove != nil {
            removeButton = RoundShadowButton(image: .init(systemName: "trash") ?? .init(), imageTintColor: .Red_03)
            removeButton!.addTarget(self, action: #selector(removeButtonTapped), for: .touchUpInside)
            imageView.addSubview(removeButton!)
            removeButton!.snp.makeConstraints { make in
                make.leading.bottom.equalToSuperview().inset(12)
            }
        }
        if _debugSettings.photoAnnotationsEnabled {
            annotationsButton = RoundShadowButton(image: .init(systemName: "scribble") ?? .init())
            annotationsButton!.addTarget(self, action: #selector(annotationsButtonTapped), for: .touchUpInside)
            imageView.addSubview(annotationsButton!)
            annotationsButton!.snp.makeConstraints { make in
                make.trailing.bottom.equalToSuperview().inset(12)
            }
        }
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

        // buttons alpha depends on the inset, so we hide the buttons if the page is shrinking (is not a central page)
        // It's hiding when inset is changing from 0 to 5
        let buttonAlpha = max(1 - imageInset.top / 5.0, 0)
        removeButton?.alpha = buttonAlpha
        annotationsButton?.alpha = buttonAlpha
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

    @objc private func pageTapped() {
        onPageTap?()
    }

    @objc private func removeButtonTapped() {
        onPhotoRemove?()
    }

    @objc private func annotationsButtonTapped() {
        onAnnotationsTap?()
    }
}

extension ImageGalleryPageView: UIGestureRecognizerDelegate {
    /// Registering tap gesture recognizer on the view will still 'touchUpInside' events from UIControls so we need to make sure
    /// that the view ignores touchs on UIControls
    func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIControl {
            return false
        }
        return true
    }
}
