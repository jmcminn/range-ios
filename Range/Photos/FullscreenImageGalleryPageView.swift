import Foundation
import UIKit

/// View displayed in the FullscreenImageGalleryViewController for 1 image.
class FullscreenImageGalleryPageView: UIView {
    /// scroll view for zooming image
    let scrollView = UIScrollView()
    /// image view presenting the image
    let imageView = UIImageView()

    /// previous image size stored to only update image metrics / calculate zoom if it changes
    var previousImageSize: CGSize = .zero

    init() {
        super.init(frame: .zero)

        setupScrollView()
        setupImageView()

        addSubview(scrollView)
        scrollView.addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// to be called when the image was (re)loaded on the page to recalculate the image view frame, zoom, etc.
    func imageUpdated() {
        guard let image = imageView.image else { return }

        if image.size != previousImageSize {
            // Remove any transform currently applied by the scroll view zooming.
            imageView.transform = .identity

            imageView.frame = CGRect(origin: .zero, size: image.size)

            scrollView.contentSize = image.size

            updateZoomScale()
            centerScrollViewContents()
        }
        previousImageSize = image.size
    }

    /// Reset to the default zoom
    func resetZoom() {
        scrollView.zoomScale = scrollView.minimumZoomScale
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        scrollView.frame = bounds
        updateZoomScale()
        centerScrollViewContents()
    }

    private func setupScrollView() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.decelerationRate = .fast
        scrollView.delegate = self
    }

    private func setupImageView() {
        imageView.contentMode = .scaleAspectFit
        imageView.kf.indicatorType = .custom(indicator: ImageLoadingIndicator())

        imageView.isUserInteractionEnabled = true

        // double tap to zoom gesture recognizer
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapZoom))
        tapRecognizer.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(tapRecognizer)
    }

    /// Handling of double tap gesture
    @objc func tapZoom() {
        if isZoomedIn() {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            scrollView.setZoomScale(scrollView.maximumZoomScale, animated: true)
        }
    }

    /// Whether it's in the default (min) zoom scale (`false`) or is zoomed in (`true`)
    private func isZoomedIn() -> Bool {
        scrollView.zoomScale != scrollView.minimumZoomScale
    }

    /// Calculate zoom scale based on the scrollView frame and image size
    private func updateZoomScale() {
        guard let image = imageView.image else { return }

        let scaleWidth = scrollView.frame.width / image.size.width
        let scaleHeight = scrollView.frame.height / image.size.height
        let minScale = min(scaleWidth, scaleHeight)

        scrollView.minimumZoomScale = minScale
        // if the photo is small and the min scale is above 1, then allow it to zoom over 1
        scrollView.maximumZoomScale = minScale >= 1 ? 1.5 : 1

        scrollView.zoomScale = scrollView.minimumZoomScale

        // scrollView.panGestureRecognizer.enabled is on by default and enabled by
        // viewWillLayoutSubviews in the container controller so disable it here
        // to prevent an interference with the container controller's pan gesture.
        //
        // This is enabled in scrollViewWillBeginZooming so panning while zoomed-in
        // is unaffected.
        scrollView.panGestureRecognizer.isEnabled = false
    }

    /// if image is smaller in some dimension than the scroll view then we need scroll view insets to center the image
    private func centerScrollViewContents() {
        var horizontalInset: CGFloat = 0
        var verticalInset: CGFloat = 0

        if scrollView.contentSize.width < bounds.width {
            horizontalInset = (bounds.width - scrollView.contentSize.width) / 2
        }
        if scrollView.contentSize.height < bounds.height {
            verticalInset = (bounds.height - scrollView.contentSize.height) / 2
        }

        if let window = window, window.screen.scale < 2.0 {
            horizontalInset = floor(horizontalInset)
            verticalInset = floor(verticalInset)
        }

        // Use `contentInset` to center the contents in the scroll view. Reasoning explained here: http://petersteinberger.com/blog/2013/how-to-center-uiscrollview/
        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }
}

/// UIScrollViewDelegate
extension FullscreenImageGalleryPageView: UIScrollViewDelegate {
    func viewForZooming(in _: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with _: UIView?) {
        scrollView.panGestureRecognizer.isEnabled = true
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with _: UIView?, atScale _: CGFloat) {
        // There is a bug, especially prevalent on iPhone 6 Plus, that causes zooming to render all other gesture recognizers ineffective.
        // This bug is fixed by disabling the pan gesture recognizer of the scroll view when it is not needed.
        if scrollView.zoomScale == scrollView.minimumZoomScale {
            scrollView.panGestureRecognizer.isEnabled = false
        }
    }
}
