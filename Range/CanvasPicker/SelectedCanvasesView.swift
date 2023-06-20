import UIKit

/// Displays a horizontally scrollable collection of CanvasViewModel(s).
class SelectedCanvasesView: UIView {
    unowned let viewModel: CanvasesViewModel
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

    /// Should it always show a special cell saying "edit" at the beginning of canvases (even if there's no selected canvases)
    private let showEditCell: Bool

    init(viewModel: CanvasesViewModel, showEditCell: Bool = false) {
        self.viewModel = viewModel
        self.showEditCell = showEditCell
        visibleState = viewModel.selectedCanvases.isEmpty && !showEditCell ? .hidden : .visible
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
        collectionView.register(SelectedCanvasCollectionViewCell.self, forCellWithReuseIdentifier: "CanvasCell")
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

extension SelectedCanvasesView {
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

// MARK: - CanvasesViewModel delegate

extension SelectedCanvasesView: CanvasesViewModelDelegate {
    /// update selected canvases when view model changes
    func canvasesViewModel(
        _: CanvasesViewModel,
        canvas _: CanvasViewModel,
        selected: Bool,
        indexInSelectedCanvases: Int
    ) {
        let indexPath = IndexPath(
            item: showEditCell ? 1 + indexInSelectedCanvases : indexInSelectedCanvases,
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

extension SelectedCanvasesView: UICollectionViewDataSource, UICollectionViewDelegate,
    UICollectionViewDelegateFlowLayout
{
    func canvas(forIndexPath indexPath: IndexPath) -> CanvasViewModel {
        viewModel.selectedCanvases[showEditCell ? indexPath.item - 1 : indexPath.item]
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        showEditCell ? 1 + viewModel.selectedCanvases.count : viewModel.selectedCanvases.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        if showEditCell, indexPath.item == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EditCell",
                                                          for: indexPath) as! EditCollectionViewCell
            cell.setVariant(.editCanvas)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "CanvasCell",
                for: indexPath
            ) as! SelectedCanvasCollectionViewCell
            let canvas = canvas(forIndexPath: indexPath)
            cell.canvasViewModel = canvas
            cell.onDeselect = { [weak self, weak canvas] in
                guard let canvas = canvas else { return }
                self?.viewModel.set(canvasWithId: canvas.id, selected: false)
            }
            return cell
        }
    }

    /// size the items based on the text width and add the additional left/right margins as defined in `SelectedUserCollectionViewCell`
    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        let isEditCell = showEditCell && indexPath.item == 0

        let name = isEditCell
            ? EditCollectionViewCell.Variant.editCanvas.label
            : canvas(forIndexPath: indexPath).name

        let nameFont = UIFont._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
        let nameWidth = name.size(withAttributes: [NSAttributedString.Key.font: nameFont]).width

        if isEditCell {
            let imageWidth = UIImage(
                systemName: EditCollectionViewCell.Variant.editCanvas.image,
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
            return CGSize(
                width: max(nameWidth, TagCollectionViewCell.minLabelWidth) +
                    SelectedCanvasCollectionViewCell.leadingLabelInset +
                    SelectedCanvasCollectionViewCell.trailingLabelInset + 1.0, // +1 to handle any rounding issues
                height: 40
            )
        }
    }
}
