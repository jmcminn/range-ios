import Kingfisher
import UIKit

/// Header view with the photo and tags/description switch
/// The layout supports collapsing the photo view
class PhotoDetailsHeaderViewController: UIViewController {
    private unowned let localFiles: LocalFiles
    /// The photo
    private let photosViewModel: PhotosToAddViewModel

    var galleryVC: ImageGalleryViewController<MediaKey>!
    var tagsDescriptionSegmentedControl: SegmentedControl!
    /// Current photo tapped
    var onPhotoSelected: (() -> Void)?
    /// Callbacks for the tags/description switch
    var onTagsSelected: (() -> Void)?
    var onDescriptionSelected: (() -> Void)?

    init(localFiles: LocalFiles, photosViewModel: PhotosToAddViewModel) {
        self.localFiles = localFiles
        self.photosViewModel = photosViewModel
        super.init(nibName: nil, bundle: nil)
        photosViewModel.addDelegate(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .dynamic(.Neutral_10)

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

    private func buildGalleryView() {
        galleryVC = ImageGalleryViewController(
            imageDataProviderFactory: { [localFiles] in
                localFiles.imageProvider(forKey: $0)
            },
            photoKeys: photosViewModel.photos.map(\.mediaKey),
            pageHeight2Width: photosViewModel.photos.map(\.height2Width).max() ?? 4.0 / 3.0,
            removePhotoHandler: { [weak self] photoIndex in
                guard let self = self else { return false }
                guard photoIndex < self.photosViewModel.photos.count else { return false }
                self.photosViewModel.remove(photoAtIndex: photoIndex)
                return true
            }
        )
        galleryVC.onPhotoSelected = { [weak self] in
            self?.onPhotoSelected?()
        }
    }

    private func buildTagsDescriptionSegmentedControl() {
        tagsDescriptionSegmentedControl = SegmentedControl(items: [
            ActionItem(
                title: String(localized: "Tags"),
                imageName: "tag",
                handler: { [weak self] in self?.onTagsSelected?() }
            ),
            ActionItem(
                title: String(localized: "Description"),
                imageName: "text.quote",
                handler: { [weak self] in self?.onDescriptionSelected?() }
            ),
        ])
    }
}

/// Delegate for photos view model to react for photo removal (photo adding cannot really happen when displaying the details)
extension PhotoDetailsHeaderViewController: PhotosToAddViewModelDelegate {
    func photoRemoved(atIndex index: Int) {
        galleryVC.photoRemoved(atIndex: index)
    }
}
