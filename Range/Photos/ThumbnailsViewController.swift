import FirebaseStorage
import FirebaseStorageSwift
import Foundation
import Kingfisher
import OSLog
import RealmSwift
import UIKit

/// Displays thumbnails (thumbnail0) for given uploads as a horizontally scrollable collection view.
/// The view is "live" meaning it observes the Uploads and reloads the collection view accordingly.
/// It uses `Images` for getting image provider for Upload and implements UICollectionViewDataSourcePrefetching for prefetching images.
class ThumbnailsViewController: UIViewController {
    unowned let images: Images
    let uploads: Results<Upload>
    var prefetcher: ImagePrefetcher?

    /// Token for observing changes in uploads
    private var notificationToken: NotificationToken?

    var collectionView: UICollectionView!

    /// cache calculated cell widths, if not cache then invalidating the layout and recalculating causes flickering in the UI
    var cellWidths: [Double?] = []

    init(images: Images, uploads: Results<Upload>) {
        self.images = images
        self.uploads = uploads
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.register(ThumbnailCollectionViewCell.self, forCellWithReuseIdentifier: "ThumbnailCell")

        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        observeUploads()
    }

    deinit {
        notificationToken?.invalidate()
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        // update the border color for cells
        collectionView.reloadData()
    }

    private func observeUploads() {
        notificationToken = uploads.observe { [weak self] (changes: RealmCollectionChange) in
            guard let self = self else { return }
            guard let collectionView = self.collectionView else { return }
            switch changes {
            case .initial:
                // reset widths to defaults
                self.cellWidths = [Double?].init(repeating: nil, count: self.uploads.count)
                collectionView.reloadData()
            case let .update(_, deletions, insertions, modifications):
                // reset the cell widths for updated items
                for deletionIndex in deletions.sorted(by: >) {
                    self.cellWidths.remove(at: deletionIndex)
                }
                for insertionIndex in insertions {
                    self.cellWidths.insert(nil, at: insertionIndex)
                }
                for modificationIndex in modifications {
                    self.cellWidths[modificationIndex] = nil
                }
                collectionView.performBatchUpdates {
                    collectionView.deleteItems(at: deletions.map { IndexPath(item: $0, section: 0) })
                    collectionView.insertItems(at: insertions.map { IndexPath(item: $0, section: 0) })
                    collectionView.reloadItems(at: modifications.map { IndexPath(item: $0, section: 0) })
                }
            case let .error(error):
                Logger.model.error("observing uploads failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Returns image data provider for given cell.
    private func imageProvider(forItemAt indexPath: IndexPath) -> ImageDataProvider {
        let upload = uploads[indexPath.item]
        return images.imageProvider(forUpload: upload, thumbnailNumber: 0)
    }
}

// MARK: - UICollectionView data source & delegate

extension ThumbnailsViewController: UICollectionViewDataSource, UICollectionViewDelegate,
    UICollectionViewDelegateFlowLayout
{
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        uploads.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "ThumbnailCell",
            for: indexPath
        ) as! ThumbnailCollectionViewCell
        cell.imageView.kf.indicatorType = .activity
        cell.imageView.kf.setImage(
            with: imageProvider(forItemAt: indexPath),
            placeholder: nil, options: nil, progressBlock: nil, completionHandler: { _ in
                // invalidate layout to recalculate aspect ratio after the image is loaded
                self.collectionView.collectionViewLayout.invalidateLayout()
            }
        )
        return cell
    }

    /// Adapt cell border color when the user interface style changes
    func collectionView(_: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt _: IndexPath) {
        cell.contentView.layer.borderColor = chooseColor(light: .Neutral_03, dark: .Neutral_07).cgColor
    }

    /// size the items based on the image aspect ratio. Cache the results in `cellWidths`.
    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        // variable width depending on the aspect ratio of the photo
        let height = 54.0

        guard cellWidths.count > indexPath.item else {
            // we don't have the cellWidths extended yet
            return CGSize(width: 72.0, height: height)
        }

        if let width = cellWidths[indexPath.item] {
            // already calculated
            return CGSize(width: width, height: height)
        }
        if let cell = collectionView.cellForItem(at: indexPath) as? ThumbnailCollectionViewCell {
            if let image = cell.imageView.image {
                cellWidths[indexPath.item] = image.size.width / image.size.height * height
            }
        }
        // calculated now?
        if let width = cellWidths[indexPath.item] {
            return CGSize(width: width, height: height)
        }
        // by default just horizontal 4:3
        return CGSize(width: 72.0, height: height)
    }
}

/// Images prefetching
extension ThumbnailsViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let sources = indexPaths
            .map { imageProvider(forItemAt: $0) }
            .map { Source.provider($0) }
        ImagePrefetcher(sources: sources).start()
    }
}
