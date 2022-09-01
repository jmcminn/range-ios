import Kingfisher
import UIKit

/// Header view with the photo and tags/description switch
/// The layout supports collapsing the photo view
class PhotoDetailsHeaderViewController: UIViewController {
    private unowned let imageCaches: ImageCaches
    /// The photo
    private let photosToAdd: [PhotoToAdd]

    var galleryVC: ImageGalleryViewController<String>!
    var tagsDescriptionSegmentedControl: SegmentedControl!
    /// Photo with given index selected
    var onPhotoSelected: ((Int) -> Void)?
    /// Callbacks for the tags/description switch
    var onTagsSelected: (() -> Void)?
    var onDescriptionSelected: (() -> Void)?

    init(imageCaches: ImageCaches, photosToAdd: [PhotoToAdd]) {
        self.imageCaches = imageCaches
        self.photosToAdd = photosToAdd
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        buildGalleryView()
        buildTagsDescriptionSegmentedControl()

        add(childController: galleryVC)
        view.addSubview(tagsDescriptionSegmentedControl)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let margin = 16.0
        let width = view.bounds.width
        let height = view.bounds.height

        tagsDescriptionSegmentedControl.frame = CGRect(
            x: margin,
            y: height - margin - SegmentedControl.height,
            width: width - 2 * margin,
            height: SegmentedControl.height
        )

        let galleryViewHeight = tagsDescriptionSegmentedControl.frame.minY - margin
        galleryVC.view.frame = CGRect(
            x: 0,
            y: tagsDescriptionSegmentedControl.frame.minY - margin - galleryViewHeight,
            width: width,
            height: galleryViewHeight
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// update colors that don't adapt automatically to appearance change
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            tagsDescriptionSegmentedControl?.updateColors()
        }
    }

    private func buildGalleryView() {
        galleryVC = ImageGalleryViewController(
            imageDataProviderFactory: { [imageCaches] in
                imageCaches.imageProvider(forLocalPhotoWithCacheKey: $0)
            },
            photoKeys: photosToAdd.map(\.cacheKey),
            pageHeight2Width: photosToAdd.map(\.height2Width).max() ?? 4.0 / 3.0
        )
        galleryVC.onPhotoSelected = { [weak self] index in
            self?.onPhotoSelected?(index)
        }
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
