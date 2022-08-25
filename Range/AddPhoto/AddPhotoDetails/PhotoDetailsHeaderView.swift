import Kingfisher
import UIKit

/// Header view with the photo and tags/description switch
/// The layout supports collapsing the photo view
class PhotoDetailsHeaderView: UIView {
    private unowned let imageCaches: ImageCaches
    /// The photo
    private let photosToAdd: [PhotoToAdd]

    var photoView: UIImageView!
    var tagsDescriptionSegmentedControl: SegmentedControl!
    /// Callbacks for the tags/description switch
    var onTagsSelected: (() -> Void)?
    var onDescriptionSelected: (() -> Void)?

    init(imageCaches: ImageCaches, photosToAdd: [PhotoToAdd]) {
        self.imageCaches = imageCaches
        self.photosToAdd = photosToAdd
        super.init(frame: .zero)

        backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)
        buildViews()
    }

    /// Creates views, adds them to header and configure the layout
    private func buildViews() {
        buildPhotoView()
        buildTagsDescriptionSegmentedControl()

        addSubview(photoView)
        addSubview(tagsDescriptionSegmentedControl)
    }

    /// layout subviews manually instead of using autolayout because we need to exactly calculate the frame for the photoView to match
    /// the photo aspect ratio.
    /// When photoView frame was wider (as wide as the superview) then animation of the header size introduced a weird effect that a
    /// photo scaled from the right side (when growing) instead of preserving the x center. This problem goes away if the frame is
    /// adjusted to exactly match the photo, so the .scaleAspectFit is only effective when the header is over expanded (so when the
    /// photo reached the maximum width)
    override func layoutSubviews() {
        let margin = 16.0
        let width = bounds.width
        let height = bounds.height

        tagsDescriptionSegmentedControl.frame = CGRect(
            x: margin,
            y: height - margin - SegmentedControl.height,
            width: width - 2 * margin,
            height: SegmentedControl.height
        )

        let photo = photosToAdd[0]

        // let's make it at least 30pt high, for smaller headers it'll disappear because of the
        // alpha control (see PhotoDetailsViewController)
        let photoViewHeight = max(30, tagsDescriptionSegmentedControl.frame.minY - margin)
        let photoViewWidth = min(width - 32, photoViewHeight / photo.height2Width)
        photoView.frame = CGRect(
            x: (width - photoViewWidth) / 2,
            y: tagsDescriptionSegmentedControl.frame.minY - margin - photoViewHeight,
            width: photoViewWidth,
            height: photoViewHeight
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// update colors that don't adapt automatically to appearance change
    func updateColors() {
        tagsDescriptionSegmentedControl?.updateColors()
    }

    private func buildPhotoView() {
        photoView = UIImageView()
        photoView.layer.cornerRadius = 13
        photoView.clipsToBounds = true
        photoView.contentMode = .scaleAspectFit
        photoView.kf.indicatorType = .activity
        photoView.kf.setImage(
            with: .provider(imageCaches.imageProvider(forLocalPhotoWithCacheKey: photosToAdd[0].cacheKey))
        )
    }

    private func buildTagsDescriptionSegmentedControl() {
        tagsDescriptionSegmentedControl = SegmentedControl(items: [
            UIAction(
                title: String(localized: "Tags"),
                image: UIImage(systemName: "tag"),
                handler: { [weak self] _ in self?.onTagsSelected?() }
            ),
            UIAction(
                title: String(localized: "Description"),
                image: UIImage(systemName: "text.quote"),
                handler: { [weak self] _ in self?.onDescriptionSelected?() }
            ),
        ])
    }
}
