import FirebaseStorage
import Foundation
import Kingfisher
import OSLog
import RealmSwift
import UIKit

/// Displays thumbnails (thumbnail0) for given uploads as a horizontally scrollable collection view.
/// The view is "live" meaning it observes the Uploads and reloads the collection view accordingly.
/// It uses `Images` for getting image provider for Upload and implements UICollectionViewDataSourcePrefetching for prefetching images.
class ThumbnailsViewController: UIViewController {
    /// Conform to hashable by checking id only, we don't want the Upload being accessed for hashing as the diffable data source
    /// will need hash when computing the diff and the Upload may already be gone (if some upload was removed)
    struct CollectionItem: Hashable {
        var id: String
        // upload is optional as the collection contains "skeleton" cells with no uploads to fill
        // the whole collection width
        var upload: Upload?
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    /// All thumbnails are rendered with this height and variable width depending on the image aspect ratio
    static let thumbnailHeight = 72.0

    unowned let mediaCache: MediaCache
    unowned let projectModel: ProjectModel
    let uploads: Results<Upload>
    var prefetcher: ImagePrefetcher?

    /// given upload was selected
    var onUploadSelected: ((Upload) -> Void)?

    /// Token for observing changes in uploads
    private var notificationToken: NotificationToken?

    var collectionView: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<Int, CollectionItem>!

    /// it only displays image uploads
    init(mediaCache: MediaCache, projectModel: ProjectModel, uploads: Results<Upload>) {
        self.mediaCache = mediaCache
        self.projectModel = projectModel
        self.uploads = uploads
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.register(ThumbnailCollectionViewCell.self, forCellWithReuseIdentifier: "ThumbnailCell")
        collectionView.register(ThumbnailSkeletonCollectionViewCell.self, forCellWithReuseIdentifier: "SkeletonCell")

        dataSource = UICollectionViewDiffableDataSource<Int, CollectionItem>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, collectionItem -> UICollectionViewCell? in
            guard let self = self else { return nil }
            return self.cell(forCollectionView: collectionView, indexPath: indexPath, collectionItem: collectionItem)
        }

        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        observeUploads()
    }

    deinit {
        notificationToken?.invalidate()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // update the border color for cells
        collectionView.reloadData()
    }

    private func observeUploads() {
        notificationToken = uploads.observe { [weak self] (changes: RealmCollectionChange) in
            guard let self = self else { return }
            switch changes {
            case .initial:
                self.dataSource.apply(self.prepareSnapshot(), animatingDifferences: false)
            case .update:
                self.dataSource.apply(self.prepareSnapshot(), animatingDifferences: true)
            case let .error(error):
                Logger.model.error("observing uploads failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Prepare new snapshot for the diffable data source - just include all Uploads as CollectionItems
    private func prepareSnapshot() -> NSDiffableDataSourceSnapshot<Int, CollectionItem> {
        var snapshot = NSDiffableDataSourceSnapshot<Int, CollectionItem>()
        snapshot.appendSections([1])
        snapshot.appendItems(uploads.map { CollectionItem(id: $0.id, upload: $0) })

        // add skeleton cells to fill the whole width (might more, just not less, thats why we assume
        // the thumbnails are narrow if no ratio given)
        let totalUploadsWidth =
            16 + // left margin
            uploads.map {
                // assume the item is narrow (portrait) if no ratio
                let imageHeightToWidth = $0.imageHeightToWidth ?? 0.75
                return ThumbnailsViewController.thumbnailHeight / imageHeightToWidth + 8 // 8 for spacing
            }
            .reduce(0.0, +)
        let emptySpace = view.bounds.width - totalUploadsWidth
        let skeletonCellWidth = ThumbnailsViewController.thumbnailHeight * 4.0 / 3.0 + 8 // assume wide + 8 spacing
        let skeletonCellsNumber = Int(ceil(emptySpace / skeletonCellWidth))
        if skeletonCellsNumber > 0 {
            let skeletonItems = Array(1 ... skeletonCellsNumber).map { CollectionItem(id: "skeleton \($0)") }
            snapshot.appendItems(skeletonItems)
        }

        return snapshot
    }

    /// Returns image data provider for given cell.
    private func imageProvider(forItemAt indexPath: IndexPath) -> RangeImageDataProvider? {
        guard indexPath.item < uploads.count else { return nil }
        let upload = uploads[indexPath.item]
        let mediaKey = MediaKey(projectId: projectModel.projectId, upload: upload, thumbnailNumber: 0)
        return mediaCache.imageProvider(forKey: mediaKey)
    }
}

// MARK: - UICollectionView delegate

extension ThumbnailsViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    /// Adapt cell border color when the user interface style changes
    func collectionView(_: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt _: IndexPath) {
        cell.contentView.layer.borderColor = chooseColor(.Neutral_07).cgColor
    }

    /// size the items based on the image aspect ratio. Cache the results in `cellWidths`.
    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        guard uploads.count > indexPath.item,
              let imageHeight2Width = uploads[indexPath.item].imageHeightToWidth,
              imageHeight2Width > 0
        else {
            // we don't have the aspect ratio for this upload yet
            return CGSize(width: 72.0, height: ThumbnailsViewController.thumbnailHeight)
        }

        let width = ThumbnailsViewController.thumbnailHeight / imageHeight2Width
        return CGSize(width: width, height: ThumbnailsViewController.thumbnailHeight)
    }

    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item < uploads.count {
            onUploadSelected?(uploads[indexPath.item])
        }
    }
}

// MARK: diffable data source

extension ThumbnailsViewController {
    func cell(forCollectionView collectionView: UICollectionView, indexPath: IndexPath,
              collectionItem: CollectionItem) -> UICollectionViewCell?
    {
        if let upload = collectionItem.upload {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "ThumbnailCell",
                for: indexPath
            ) as! ThumbnailCollectionViewCell
            if upload.isImage {
                cell.imageDataProvider = imageProvider(forItemAt: indexPath)
            }
            cell.upload = upload
            return cell
        } else {
            // skeleton
            return collectionView.dequeueReusableCell(withReuseIdentifier: "SkeletonCell", for: indexPath)
        }
    }
}

/// Images prefetching
extension ThumbnailsViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        guard indexPaths.count > 0 else { return }
        guard let firstImageDataProvider = imageProvider(forItemAt: indexPaths[0]) else { return }
        let sources = indexPaths
            .compactMap { imageProvider(forItemAt: $0) }
            .map { Source.provider($0) }
        ImagePrefetcher(sources: sources, options: [.targetCache(firstImageDataProvider.cache)]).start()
    }
}
