import Foundation
import Kingfisher
import OSLog
import Realm
import RealmSwift
import UIKit

/// Card view controller presenting a grid view of uploads.
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class MediaCardViewController: SheetCardViewController {
    private let projectModel: ProjectModel
    private let imageCaches: ImageCaches

    /// uploads to show
    private let uploads: Results<Upload>

    var onUploadSelected: ((Upload) -> Void)?

    private let headerStroke = UIView()
    private let collectionView: UICollectionView

    private var headerFont: UIFont {
        // for some reason the dynamic font only works when the font is created anew every time it's reloaded
        ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
    }

    /// Conform to hashable by checking id only, we don't want the Upload being accessed for hashing as the diffable data source
    /// will need hash when computing the diff and the Upload may already be gone (if some upload was removed)
    struct CollectionItem: Hashable {
        var id: String
        var upload: Upload
        init(_ upload: Upload) {
            id = upload.id
            self.upload = upload
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    private var dataSource: UICollectionViewDiffableDataSource<String, CollectionItem>!

    /// Token for observing changes in uploads
    private var notificationToken: NotificationToken?

    /// Initializer
    ///
    /// - Parameters:
    ///     - title:                    title of the card
    ///     - users:                 users to show in the picker
    init(
        projectModel: ProjectModel,
        imageCaches: ImageCaches,
        title: String,
        uploads: Results<Upload>,
        onUploadSelected: ((Upload) -> Void)? = nil
    ) {
        self.projectModel = projectModel
        self.imageCaches = imageCaches
        self.uploads = uploads

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(icon: UIImage(systemName: "photo"), title: title)
        self.onUploadSelected = onUploadSelected
    }

    deinit {
        notificationToken?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHeaderStroke()
        sheetHeaderView.addSubview(headerStroke)
        headerStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }

        setupCollectionView()
        containerView.insertSubview(collectionView, belowSubview: sheetHeaderView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        observeUploads()
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        // update the border color for cells
        collectionView.reloadData()
        updateHeaderShadow()
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

    /// Prepare new snapshot for the diffable data source
    /// Include all Uploads grouping by day into sections
    private func prepareSnapshot() -> NSDiffableDataSourceSnapshot<String, CollectionItem> {
        var sectionName = ""

        let uploads = uploads.sorted(by: \Upload.timestamp, ascending: false)

        var snapshot = NSDiffableDataSourceSnapshot<String, CollectionItem>()
        var sectionItems = [CollectionItem]()

        let appendSection = {
            if !sectionItems.isEmpty {
                // add number of photos to section name (after all photos were collected for given section)
                let photosString = sectionItems.count > 1 ? "photos" : "photo"
                snapshot.appendSections(["\(sectionName) • \(sectionItems.count) \(photosString)"])
                snapshot.appendItems(sectionItems)
            }
        }

        for upload in uploads {
            let uploadSectionName = Date.formatMediaHeader(upload.timestamp)
            // put uploads with same formatted timestamp into one section
            if uploadSectionName != sectionName {
                // close previous section
                appendSection()
                // new section
                sectionName = uploadSectionName
                sectionItems.removeAll()
            }
            sectionItems.append(CollectionItem(upload))
        }
        appendSection()
        return snapshot
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .max {
            // just make it max, so it doesn't depend on the content height (because we want to
            // show the keyboard for searching anyway, so no point in changing the card position
            // back and forth when showing/hiding the keyboard)
            return Double.greatestFiniteMagnitude
        } else {
            return super.height(forContainer: cardContainerView, cardPosition: cardPosition)
        }
    }

    override func drivingScrollView() -> UIScrollView? {
        collectionView
    }

    private func setupHeaderStroke() {
        headerStroke.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_07)
    }

    private func setupCollectionView() {
        collectionView.prefetchDataSource = self
        collectionView.delegate = self
        collectionView.register(MediaCollectionViewCell.self, forCellWithReuseIdentifier: "MediaCell")
        collectionView.register(
            MediaCollectionViewHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "Header"
        )

        dataSource = UICollectionViewDiffableDataSource<String, CollectionItem>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, collectionItem -> UICollectionViewCell? in
            guard let self = self else { return nil }
            return self.cell(forCollectionView: collectionView, indexPath: indexPath, collectionItem: collectionItem)
        }
        dataSource.supplementaryViewProvider =
            { [weak self] collectionView, elementKind, indexPath -> UICollectionReusableView? in
                guard let self = self else { return nil }
                return self.supplementaryView(
                    forCollectionView: collectionView,
                    elementKind: elementKind,
                    indexPath: indexPath
                )
            }
    }

    /// updates shadow color based on the interface style and visibility based on the `bottomStrokeVisible`
    private func updateHeaderShadow() {
        let shadowVisible = collectionView.contentOffset.y > 0
        if shadowVisible {
            let darkMode = traitCollection.userInterfaceStyle == .dark
            if darkMode {
                sheetHeaderView.setShadowWithFigmaValues(x: 0, y: 6, blur: 10, opacity: 0.1)
            } else {
                sheetHeaderView.setShadowWithFigmaValues(x: 0, y: 3, blur: 6, opacity: 0.1)
            }
            // make the shadow height = 10 points, so the top part of the shadow is not visible
            // (the path covers bottom part of the view only)
            // This only works if the view is actually higher than 10 points. But if it's lower
            // then the shadow with no shadowPath would not be shown (for view that has 0 height)
            // so we still need to "cover" this view from top with another view (in a view that's
            // adding this view controller as a child)
            sheetHeaderView.layer.shadowPath = UIBezierPath(rect: CGRect(x: 0,
                                                                         y: sheetHeaderView.bounds.maxY - 10,
                                                                         width: sheetHeaderView.bounds.width,
                                                                         height: 10)).cgPath
        } else {
            sheetHeaderView.layer.shadowOpacity = 0
        }
    }
}

extension MediaCardViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    /// Size the items so there are 3 items in a row
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt _: IndexPath
    ) -> CGSize {
        guard let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout else { return .zero }
        let availableWidth = collectionView.bounds.width - flowLayout.sectionInset.left - flowLayout.sectionInset.right

        let itemWidth = floor((availableWidth + flowLayout.minimumInteritemSpacing) / 3 - flowLayout
            .minimumInteritemSpacing)

        return CGSize(width: itemWidth, height: itemWidth)
    }

    /// Calculated the header height based on the header name and font
    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> CGSize
    {
        guard let sectionName = dataSource.sectionIdentifier(for: section) else {
            return .zero
        }
        let nameHeight = sectionName._heightWithConstrainedWidth(
            width: collectionView.bounds.width - 2 * MediaCollectionViewHeader.horizontalInset,
            font: headerFont
        )
        let height = section == 0
            ? 16.0 + nameHeight // first section needs the 16 points top padding
            : nameHeight
        return CGSize(width: 1, height: height)
    }

    func scrollViewDidScroll(_: UIScrollView) {
        updateHeaderShadow()
    }
}

// MARK: diffable data source

extension MediaCardViewController {
    func cell(forCollectionView collectionView: UICollectionView, indexPath: IndexPath,
              collectionItem: CollectionItem) -> UICollectionViewCell?
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MediaCell",
                                                      for: indexPath) as! MediaCollectionViewCell

        let upload = collectionItem.upload
        let uploadCacheKey = uploadKey(projectId: projectModel.projectId, uploadId: upload.id, thumbnailNumber: 1)
        let imageDataProvider = imageCaches.imageProvider(forPhotoWithCacheKey: uploadCacheKey)
        cell.setUpload(upload, imageDataProvider: imageDataProvider)

        return cell
    }

    func supplementaryView(forCollectionView collectionView: UICollectionView, elementKind: String,
                           indexPath: IndexPath) -> UICollectionReusableView?
    {
        if elementKind == UICollectionView.elementKindSectionHeader {
            let headerView = collectionView.dequeueReusableSupplementaryView(
                ofKind: elementKind,
                withReuseIdentifier: "Header",
                for: indexPath
            ) as! MediaCollectionViewHeader
            // for some reason if the font is not reset here the dynamic font sizing won't work
            headerView.label.font = headerFont
            if let sectionName = dataSource.sectionIdentifier(for: indexPath.section) {
                headerView.label.text = sectionName
            }
            return headerView
        }
        return nil
    }
}

// MARK: - Images prefetching

extension MediaCardViewController: UICollectionViewDataSourcePrefetching {
    /// map indexPath to CollectionItem from the current diffable data source snapshot and return the image provider for it's upload id
    func imageProvider(forItemAt indexPath: IndexPath) -> RangeImageDataProvider? {
        guard let sectionId = dataSource.sectionIdentifier(for: indexPath.section) else { return nil }
        let sectionUploads = dataSource.snapshot(for: sectionId).items
        guard indexPath.item < sectionUploads.count else { return nil }
        let uploadCacheKey = uploadKey(
            projectId: projectModel.projectId,
            uploadId: sectionUploads[indexPath.item].id,
            thumbnailNumber: 1
        )
        return imageCaches.imageProvider(forPhotoWithCacheKey: uploadCacheKey)
    }

    func collectionView(_: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let sources = indexPaths
            .compactMap { imageProvider(forItemAt: $0) }
            .map { Source.provider($0) }
        ImagePrefetcher(sources: sources).start()
    }
}
