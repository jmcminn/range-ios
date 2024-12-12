import UIKit

/// Displays a horizontally scrollable collection of ItemPickerItem(s).
class SelectedItemPickerItemsView: UIView {
    struct Config {
        // if nil then don't show the edit cell
        var editCellVariant: EditCollectionViewCell.Variant?
        // the icon to display to the left of the name for each selected item
        var itemIconSystemName: String?

        var showEditCell: Bool { editCellVariant != nil }
    }

    unowned let viewModel: ItemPickerViewModel
    let config: Config
    var collectionView: UICollectionView!

    /// The view can be shown or hidden. But for layout purposes it is important to know about 1 more state - `transitioning`,
    /// which is a temporary state when animating between visible and hidden
    enum VisibleState {
        case visible // selected users are shown
        case transitioning // selected users are being animated in or out
        case hidden // selected users are hidden
    }

    /// current state
    private(set) var visibleState: VisibleState

    init(viewModel: ItemPickerViewModel, config: Config) {
        self.viewModel = viewModel
        self.config = config
        visibleState = viewModel.selectedItems.isEmpty && !config.showEditCell ? .hidden : .visible
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
        collectionView.register(SelectedItemPickerItemCollectionViewCell.self, forCellWithReuseIdentifier: "ItemCell")
        collectionView.register(EditCollectionViewCell.self, forCellWithReuseIdentifier: "EditCell")

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

extension SelectedItemPickerItemsView {
    func visibleStateWillTransition() {
        visibleState = .transitioning
    }

    /// animate the visibility of users
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

// MARK: - ItemPickerViewModelDelegate delegate

extension SelectedItemPickerItemsView: ItemPickerViewModelDelegate {
    /// update selected item when view model changes
    func itemPickerViewModel(
        _: ItemPickerViewModel,
        item _: ItemPickerItem,
        selected: Bool,
        indexInSelectedItems: Int
    ) {
        let indexPath = IndexPath(
            item: config.showEditCell ? 1 + indexInSelectedItems : indexInSelectedItems,
            section: 0
        )
        if selected {
            collectionView.insertItems(at: [indexPath])
            collectionView.scrollToItem(at: indexPath, at: .right, animated: true)
        } else {
            collectionView.deleteItems(at: [indexPath])
        }
    }
}

// MARK: - UICollectionView data source & delegate

extension SelectedItemPickerItemsView: UICollectionViewDataSource, UICollectionViewDelegate,
    UICollectionViewDelegateFlowLayout
{
    func item(forIndexPath indexPath: IndexPath) -> ItemPickerItem {
        viewModel.selectedItems[config.showEditCell ? indexPath.item - 1 : indexPath.item]
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        config.showEditCell ? 1 + viewModel.selectedItems.count : viewModel.selectedItems.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        if let editCellVariant = config.editCellVariant, indexPath.item == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EditCell",
                                                          for: indexPath) as! EditCollectionViewCell
            cell.setVariant(editCellVariant)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "ItemCell",
                for: indexPath
            ) as! SelectedItemPickerItemCollectionViewCell
            let item = item(forIndexPath: indexPath)
            cell.setItem(item, imageSystemName: config.itemIconSystemName)
            cell.onDeselect = { [weak self, weak item] in
                guard let item else { return }
                self?.viewModel.set(itemWithId: item.id, selected: false)
            }
            return cell
        }
    }

    /// size the items based on the text width and add the additional left/right margins as defined in `SelectedUserCollectionViewCell`
    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        let isEditCell = config.showEditCell && indexPath.item == 0

        let name = isEditCell ? config.editCellVariant!.label : item(forIndexPath: indexPath).name

        let nameFont = UIFont._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
        let nameWidth = name.size(withAttributes: [NSAttributedString.Key.font: nameFont]).width

        if isEditCell {
            let imageWidth = UIImage(
                systemName: config.editCellVariant!.image,
                withConfiguration: UIImage.SymbolConfiguration(font: nameFont)
            )?.size.width ?? 0
            let contentWidth = imageWidth + EditCollectionViewCell.imageToLabelDistance + nameWidth
            return CGSize(
                width: max(contentWidth, TagCollectionViewCell.minLabelWidth) +
                    TagCollectionViewCell.leadingLabelInset +
                    TagCollectionViewCell.trailingLabelInset + 1.0, // +1 to handle any rounding issues
                height: 40
            )
        } else {
            let imageWidth: CGFloat
            if item(forIndexPath: indexPath).icon != nil {
                imageWidth = 20 + SelectedItemPickerItemCollectionViewCell.imageToLabelOffset
            } else if let cellIconName = config.itemIconSystemName, let cellImage = UIImage(
                systemName: cellIconName,
                withConfiguration: UIImage
                    .SymbolConfiguration(font: ._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold))
            ) {
                imageWidth = cellImage.size.width + SelectedItemPickerItemCollectionViewCell.imageToLabelOffset
            } else {
                imageWidth = 0
            }
            return CGSize(
                width: max(imageWidth + nameWidth, TagCollectionViewCell.minLabelWidth) +
                    SelectedItemPickerItemCollectionViewCell.leadingInset +
                    SelectedItemPickerItemCollectionViewCell.trailingLabelInset + 1.0,
                // +1 to handle any rounding issues
                height: 40
            )
        }
    }
}
