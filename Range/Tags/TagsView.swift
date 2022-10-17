import Foundation
import OSLog
import RealmSwift
import UIKit

/// Displays a horizontally scrollable collection of `Tag`s
class TagsView: UIView {
    /// Collection item needs id and name to uniquely identify the tag. Do not store tag here as it's managed by Realm and may
    /// be removed and no longer accessible when diffable data source needs to compute the diff
    /// By storing the name directly and using it for hash, the item will be updated if the name changes
    /// There's one special collection item - when `addTag` is `true` it show an "add" tag cell
    struct CollectionItem: Hashable {
        var id: String
        var name: String
        var addTag: Bool = false
    }

    /// Should it always show a special cell saying "add" at the end of tags (even if tags results are empty)
    var showAddTagCell: Bool = false
    var tags: Results<Tag>? {
        didSet {
            if let tags = tags {
                observeTags(tags: tags)
            } else {
                applyNewSnapshot(animatingDifferences: false)
                notificationToken?.invalidate()
            }
        }
    }

    private let layout = UICollectionViewFlowLayout()
    let collectionView: UICollectionView
    var dataSource: UICollectionViewDiffableDataSource<Int, CollectionItem>!
    /// Token for observing changes in tags
    private var notificationToken: NotificationToken?

    /// insets for tap area, to make the tap area larger provide negative values
    private var tapAreaInsets: UIEdgeInsets = .init(top: -6, left: 0, bottom: -6, right: 0)

    /// This view is quite low (32), make it respond to touches above and below (see the tapAreaInsets)
    override func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        let newArea = CGRect(
            x: bounds.origin.x + tapAreaInsets.left,
            y: bounds.origin.y + tapAreaInsets.top,
            width: bounds.size.width - tapAreaInsets.left - tapAreaInsets.right,
            height: bounds.size.height - tapAreaInsets.top - tapAreaInsets.bottom
        )
        return newArea.contains(point)
    }

    init() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)

        setupView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        notificationToken?.invalidate()
    }

    func setupView() {
        backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)

        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        collectionView.delegate = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.register(TagCollectionViewCell.self, forCellWithReuseIdentifier: "TagCell")
        collectionView.register(TagAddCollectionViewCell.self, forCellWithReuseIdentifier: "TagAddCell")

        dataSource = UICollectionViewDiffableDataSource<Int, CollectionItem>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, collectionItem -> UICollectionViewCell? in
            self?.cell(forCollectionView: collectionView, indexPath: indexPath, collectionItem: collectionItem)
        }

        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    /// if there's not tags the intrinsic height is 0
    override var intrinsicContentSize: CGSize {
        if showAddTagCell {
            // no matter how many tags always show something
            return CGSize(width: UIView.noIntrinsicMetric, height: 32)
        } else if let tags = tags, tags.count > 0 {
            return CGSize(width: UIView.noIntrinsicMetric, height: 32)
        } else {
            return CGSize(width: UIView.noIntrinsicMetric, height: 0)
        }
    }

    private func observeTags(tags: Results<Tag>) {
        notificationToken = tags.observe { [weak self] (changes: RealmCollectionChange) in
            guard let self = self else { return }
            switch changes {
            case .initial:
                self.applyNewSnapshot(animatingDifferences: false)
            case .update:
                self.applyNewSnapshot(animatingDifferences: true)
            case let .error(error):
                Logger.model.error("observing tags failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Apply snapshot and invalidate intrinsic content size
    private func applyNewSnapshot(animatingDifferences: Bool) {
        dataSource.apply(prepareSnapshot(), animatingDifferences: animatingDifferences)
        invalidateIntrinsicContentSize()
    }

    /// Prepare new snapshot for the diffable data source - just include all Uploads as CollectionItems
    private func prepareSnapshot() -> NSDiffableDataSourceSnapshot<Int, CollectionItem> {
        var snapshot = NSDiffableDataSourceSnapshot<Int, CollectionItem>()
        snapshot.appendSections([1])
        if let tags = tags {
            snapshot.appendItems(tags.map { CollectionItem(id: $0.id, name: $0.name) })
        }
        if showAddTagCell {
            snapshot.appendItems([CollectionItem(id: "add", name: TagAddCollectionViewCell.labelText, addTag: true)])
        }
        return snapshot
    }
}

// MARK: - UICollectionView data source & delegate

extension TagsView: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    /// size the items based on the text width and add the additional left/right margins as defined in `TagCollectionViewCell`
    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        guard let tags = tags else { return .zero }
        if showAddTagCell {
            guard indexPath.item <= tags.count else { return .zero }
        } else {
            guard indexPath.item < tags.count else { return .zero }
        }

        let contentWidth: CGFloat
        if indexPath.item == tags.count {
            // this is the last special "add" tag
            let name = TagAddCollectionViewCell.labelText
            let nameWidth = name.size(withAttributes: [
                NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption1),
            ]).width
            let imageWidth = TagAddCollectionViewCell.tagImage?.size.width ?? 0
            contentWidth = imageWidth + TagAddCollectionViewCell.imageToLabelDistance + nameWidth
        } else {
            let name = tags[indexPath.item].name
            contentWidth = name.size(withAttributes: [
                NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2),
            ]).width
        }
        return CGSize(
            width: max(contentWidth, TagCollectionViewCell.minLabelWidth) +
                TagCollectionViewCell.leadingLabelInset +
                TagCollectionViewCell.trailingLabelInset + 1.0, // +1 to handle any rounding issues
            height: 32
        )
    }
}

// MARK: diffable data source

extension TagsView {
    func cell(forCollectionView collectionView: UICollectionView, indexPath: IndexPath,
              collectionItem: CollectionItem) -> UICollectionViewCell?
    {
        if collectionItem.addTag {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "TagAddCell", for: indexPath)
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagCell",
                                                          for: indexPath) as! TagCollectionViewCell
            cell.tagName = collectionItem.name
            cell.tapAreaInsets = tapAreaInsets
            return cell
        }
    }
}
