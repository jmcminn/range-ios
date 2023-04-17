import UIKit

/// Displays a horizontally scrollable collection of TagViewModel(s).
class SelectedTagsView: UIView {
    unowned let viewModel: TagsViewModel
    var collectionView: UICollectionView!

    /// The view can be shown or hidden. But for layout purposes it is important to know about 1 more state - `transitioning`,
    /// which is a temporary state when animating between visible and hidden
    enum VisibleState {
        case visible // selected tags are shown
        case transitioning // selected tags are being animated in or out
        case hidden // selected tags are hidden
    }

    /// current state
    private(set) var visibleState: VisibleState

    init(viewModel: TagsViewModel) {
        self.viewModel = viewModel
        visibleState = viewModel.selectedTags.isEmpty ? .hidden : .visible
        super.init(frame: .zero)

        viewModel.addDelegate(self)

        setupView()
    }

    /// This view is 40 points high, even though the visible height of the cells is 32 (but we want the bigger tap area)
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 40)
    }

    private func setupView() {
        backgroundColor = .dynamic(.Neutral_10)

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.register(SelectedTagCollectionViewCell.self, forCellWithReuseIdentifier: "SelectedTagCell")

        addSubview(collectionView)
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

// MARK: - showing/hiding

extension SelectedTagsView {
    func visibleStateWillTransition() {
        visibleState = .transitioning
    }

    /// animate the visibility of tags
    func setVisible(_ visible: Bool,
                    animated: Bool = true,
                    completion: (() -> Void)? = nil)
    {
        // only animate if it's not visible and showing or visible and hiding
        guard (visible == true && visibleState != .visible) ||
            (visible == false && visibleState != .hidden) else { return }

        isHidden = false
        if visible {
            alpha = 0.0 // prepare for show
        } else {
            alpha = 1.0 // prepare for hide
        }
        let applyChange = {
            self.alpha = visible ? 1.0 : 0.0
            self.isHidden = !visible
            self.visibleState = visible ? .visible : .hidden
        }
        if animated {
            UIView.animate(withDuration: 0.1) { applyChange() } completion: { _ in
                completion?()
            }
        } else {
            applyChange()
            completion?()
        }
    }
}

// MARK: - TagsViewModel delegate

extension SelectedTagsView: TagsViewModelDelegate {
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

extension SelectedTagsView: UICollectionViewDataSource, UICollectionViewDelegate,
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
            NSAttributedString.Key.font: UIFont._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold),
        ])
        return CGSize(
            width: nameSize.width + SelectedTagCollectionViewCell.leadingLabelInset + SelectedTagCollectionViewCell
                .trailingLabelInset + 1.0, // +1 to handle any rounding issues
            height: 40 // higher than in design as we want to respond to bigger tap area
        )
    }
}
