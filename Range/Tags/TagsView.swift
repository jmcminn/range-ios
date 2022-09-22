import Foundation
import OSLog
import RealmSwift
import UIKit

/// Displays a horizontally scrollable collection of `Tag`s
class TagsView: UIView {
    /// Collection item needs id and name to uniquely identify the tag. Do not store tag here as it's managed by Realm and may\
    /// be removed and no longer accessible when diffable data source needs to compute the diff
    /// By storing the name directly and using it for hash, the item will be updated if the name changes
    struct CollectionItem: Hashable {
        var id: String
        var name: String
    }

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

        dataSource = UICollectionViewDiffableDataSource<Int, CollectionItem>(
            collectionView: collectionView
        ) { collectionView, indexPath, collectionItem -> UICollectionViewCell? in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "TagCell",
                for: indexPath
            ) as! TagCollectionViewCell
            cell.tagName = collectionItem.name
            return cell
        }

        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    /// if there's not tags the intrinsic height is 0
    override var intrinsicContentSize: CGSize {
        if let tags = tags, tags.count > 0 {
            return CGSize(width: UIView.noIntrinsicMetric, height: 44)
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
        return snapshot
    }
}

// MARK: - UICollectionView data source & delegate

extension TagsView: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    /// size the items based on the text width and add the additional left/right margins as defined in `TagCollectionViewCell`
    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        guard let tags = tags, indexPath.item < tags.count else { return .zero }
        let name = tags[indexPath.item].name
        let nameSize = name.size(withAttributes: [
            NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2),
        ])
        return CGSize(
            width: max(nameSize.width, TagCollectionViewCell.minLabelWidth) +
                TagCollectionViewCell.leadingLabelInset +
                TagCollectionViewCell.trailingLabelInset + 1.0, // +1 to handle any rounding issues
            height: 44 // higher than in design as we want to respond to bigger tap area
        )
    }
}
