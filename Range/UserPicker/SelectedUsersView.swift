import UIKit

/// Displays a horizontally scrollable collection of UserViewModel(s).
class SelectedUsersView: UIView {
    unowned let viewModel: UsersViewModel
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

    /// Should it always show a special cell saying "edit" at the beginning of users (even if there's no selected users)
    private let showEditUserCell: Bool

    init(viewModel: UsersViewModel, showEditUserCell: Bool = false) {
        self.viewModel = viewModel
        self.showEditUserCell = showEditUserCell
        visibleState = viewModel.selectedUsers.isEmpty && !showEditUserCell ? .hidden : .visible
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
        collectionView.register(SelectedUserCollectionViewCell.self, forCellWithReuseIdentifier: "UserCell")
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

extension SelectedUsersView {
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

// MARK: - UsersViewModel delegate

extension SelectedUsersView: UsersViewModelDelegate {
    /// update selected users when view model changes
    func usersViewModel(_: UsersViewModel, user _: UserViewModel, selected: Bool, indexInSelectedUsers: Int) {
        let indexPath = IndexPath(item: showEditUserCell ? 1 + indexInSelectedUsers : indexInSelectedUsers, section: 0)
        if selected {
            collectionView.insertItems(at: [indexPath])
            collectionView.scrollToItem(at: indexPath, at: .right, animated: true)
        } else {
            collectionView.deleteItems(at: [indexPath])
        }
    }
}

// MARK: - UICollectionView data source & delegate

extension SelectedUsersView: UICollectionViewDataSource, UICollectionViewDelegate,
    UICollectionViewDelegateFlowLayout
{
    func user(forIndexPath indexPath: IndexPath) -> UserViewModel {
        viewModel.selectedUsers[showEditUserCell ? indexPath.item - 1 : indexPath.item]
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        showEditUserCell
            ? 1 + viewModel.selectedUsers.count
            : viewModel.selectedUsers.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        if showEditUserCell, indexPath.item == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EditCell",
                                                          for: indexPath) as! EditCollectionViewCell
            cell.setVariant(.editUser)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "UserCell",
                for: indexPath
            ) as! SelectedUserCollectionViewCell
            let user = user(forIndexPath: indexPath)
            let avatarImage = viewModel.model.mainRealm.object(ofType: Participant.self, forPrimaryKey: user.id)?
                .avatarImage
            cell.setUser(user, avatarImage: avatarImage)
            cell.onDeselect = { [weak self, weak user] in
                guard let user = user else { return }
                self?.viewModel.set(userWithId: user.id, selected: false)
            }
            return cell
        }
    }

    /// size the items based on the text width and add the additional left/right margins as defined in `SelectedUserCollectionViewCell`
    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        let isEditUserCell = showEditUserCell && indexPath.item == 0

        let name = isEditUserCell
            ? EditCollectionViewCell.Variant.editUser.label
            : user(forIndexPath: indexPath).name
        let nameFont = UIFont._preferredFont(forTextStyle: .footnote, symbolicTraits: .traitBold)
        let nameWidth = name.size(withAttributes: [NSAttributedString.Key.font: nameFont]).width
        if isEditUserCell {
            // this is the last special "add" tag
            let imageWidth = UIImage(
                systemName: EditCollectionViewCell.Variant.editUser.image,
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
                    SelectedUserCollectionViewCell.leadingLabelInset +
                    SelectedUserCollectionViewCell.trailingLabelInset + 1.0, // +1 to handle any rounding issues
                height: 40
            )
        }
    }
}
