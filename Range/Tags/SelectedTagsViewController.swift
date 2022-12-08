import UIKit

/// Displays a horizontally scrollable collection of TagViewModel(s).
class SelectedTagsViewController: UIViewController {
    unowned let viewModel: TagsViewModel
    var collectionView: UICollectionView!

    init(viewModel: TagsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        viewModel.addDelegate(self)
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
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.register(SelectedTagCollectionViewCell.self, forCellWithReuseIdentifier: "SelectedTagCell")

        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        collectionView.reloadData()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - TagsViewModel delegate

extension SelectedTagsViewController: TagsViewModelDelegate {
    /// update selected tags when view model changes
    func tagsViewModel(_: TagsViewModel, tag _: TagViewModel, selected: Bool, indexInSelectedTags: Int) {
        let indexPath = IndexPath(item: indexInSelectedTags, section: 0)
        if selected {
            collectionView.insertItems(at: [indexPath])
            collectionView.scrollToItem(at: indexPath, at: .right, animated: true)
        } else {
            collectionView.deleteItems(at: [indexPath])
        }
    }
}

// MARK: - UICollectionView data source & delegate

extension SelectedTagsViewController: UICollectionViewDataSource, UICollectionViewDelegate,
    UICollectionViewDelegateFlowLayout
{
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        viewModel.selectedTags.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "SelectedTagCell",
            for: indexPath
        ) as! SelectedTagCollectionViewCell
        let tag = viewModel.selectedTags[indexPath.item]
        cell.tagViewModel = tag
        cell.onDeselect = { [weak self, weak tag] in
            guard let tag = tag else { return }
            self?.viewModel.set(tagWithId: tag.id, selected: false)
        }
        return cell
    }

    /// size the items based on the text width and add the additional left/right margins as defined in `TagCollectionViewCell`
    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        let name = viewModel.selectedTags[indexPath.item].name
        let nameSize = name.size(withAttributes: [
            NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2),
        ])
        return CGSize(
            width: nameSize.width + SelectedTagCollectionViewCell.leadingLabelInset + SelectedTagCollectionViewCell
                .trailingLabelInset + 1.0, // +1 to handle any rounding issues
            height: 48 // higher than in design as we want to respond to bigger tap area
        )
    }
}
