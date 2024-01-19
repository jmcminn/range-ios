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
    /// The mode in which the Media card is currently operating
    private enum Mode {
        case normal // showing media
        case select // selecting media
    }

    private let projectModel: ProjectModel
    private let mediaCache: MediaCache

    /// uploads to show
    private let uploads: Results<Upload>

    private var emptyUploadsView: UIView?
    private var emptyFilteredUploadsView: UIView?

    private let collectionView: UICollectionView

    unowned let canvasContainer: CanvasContainerViewController

    private var headerFont: UIFont {
        // for some reason the dynamic font only works when the font is created anew every time it's reloaded
        ._preferredFont(forTextStyle: .callout, symbolicTraits: .traitBold)
    }

    private var selectButton: RangeButton!
    private var mode: Mode = .normal

    private var bulkActionsBottomBar: UIView?
    private var selectedMediaCountLabel: UILabel?
    private var bulkActionsButton: UIButton?

    private let mediaFilters = MediaFilters()
    private let mediaFiltersButton = RoundShadowButton(image: UIImage(named: "filter.search") ?? UIImage())
    private let filtersIndicatorBadge = BadgeView()

    /// Conform to hashable by checking id only, we don't want the Upload being accessed for hashing as the diffable data source
    /// will need hash when computing the diff and the Upload may already be gone (if some upload was removed)
    struct CollectionItem: Hashable {
        var id: String
        var upload: Upload
        var selected: Bool = false
        init(_ upload: Upload) {
            id = upload.id
            self.upload = upload
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    private var dataSource: UICollectionViewDiffableDataSource<String, CollectionItem>!
    /// indices of selected sections
    private var selectedSections = Set<Int>()
    /// ids of selected uploads
    /// Don't rely on collectionView.indexPathsForSelectedItems as it doesn't survive reloading of collection view data
    private var selectedUploads = Set<String>()

    /// Token for observing changes in uploads
    private var notificationToken: NotificationToken?

    /// Initializer
    ///
    /// - Parameters:
    ///     - title:                    title of the card
    ///     - users:                 users to show in the picker
    init(
        projectModel: ProjectModel,
        mediaCache: MediaCache,
        title: String,
        uploads: Results<Upload>,
        canvasContainer: CanvasContainerViewController
    ) {
        self.projectModel = projectModel
        self.mediaCache = mediaCache
        self.uploads = uploads
        self.canvasContainer = canvasContainer

        let layout = LeftAlignedCollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(icon: UIImage(systemName: "photo"), title: title)
    }

    deinit {
        notificationToken?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addSheetHeaderStroke()
        addSheetHeaderShadowBasedOnDrivingScrollView()

        setupSelectButton()

        setupCollectionView()
        containerView.insertSubview(collectionView, belowSubview: sheetHeaderView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        setupMediaFiltersButton()
        setupFiltersIndicatorBadge()

        onUploadsChanged()

        observeUploads()
        NotificationCenter.default.addObserver(
            self, selector: #selector(mediaFiltersUpdated),
            name: MediaFilters.UpdateNotificationName, object: nil
        )
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
            case let .update(_, _, _, modifications):
                // reload uplods
                // if there are some modifications then reload the collection view data as the cells
                // don't listen for changes (reload data is ok in media view, we don't need any animations here)
                reloadUploads(reloadCollectionView: !modifications.isEmpty)
            case let .error(error):
                Logger.model.error("observing uploads failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Prepare new snapshot for the diffable data source
    /// Include all Uploads grouping by day into sections
    private func prepareSnapshot() -> NSDiffableDataSourceSnapshot<String, CollectionItem> {
        var sectionName = ""

        let uploads = filteredUploads.sorted(using: SortDescriptor(\Upload.timestamp, order: .reverse))

        var snapshot = NSDiffableDataSourceSnapshot<String, CollectionItem>()
        var sectionItems = [CollectionItem]()

        let appendSection = {
            if !sectionItems.isEmpty {
                // add number of photos to section name (after all photos were collected for given section)
                let photosCount = sectionItems.filter(\.upload.isImage).count
                if photosCount > 0 {
                    let photosString = photosCount > 1 ? "photos" : "photo"
                    snapshot.appendSections(["\(sectionName) • \(photosCount) \(photosString)"])
                } else {
                    snapshot.appendSections([sectionName])
                }
                // re-sort section items so images are first and documents next
                let sortedSectionItems = sectionItems.sorted { item1, item2 in
                    let u1 = item1.upload
                    let u2 = item2.upload
                    if u1.isImage != u2.isImage {
                        return u1.isImage
                    }
                    return u1.timestamp > u2.timestamp
                }
                snapshot.appendItems(sortedSectionItems)
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

    private func setupCollectionView() {
        collectionView.prefetchDataSource = self
        collectionView.delegate = self
        collectionView.register(ImageMediaCollectionViewCell.self, forCellWithReuseIdentifier: "ImageCell")
        collectionView.register(DocumentMediaCollectionViewCell.self, forCellWithReuseIdentifier: "DocumentCell")
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

        collectionView
            .addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress)))
    }

    private func setupSelectButton() {
        guard selectButton == nil else { return }
        var config = UIButton.Configuration.filled()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        config.baseBackgroundColor = .dynamic(.Neutral_09)
        config.baseForegroundColor = .dynamic(.Neutral_04)
        config.cornerStyle = .fixed
        config.background.cornerRadius = 15
        config.background.strokeColor = .dynamic(.Neutral_07)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: .subheadline)
            return outgoing
        }
        selectButton = RangeButton(
            configuration: config,
            primaryAction: UIAction(title: String(localized: "Select")) { [weak self] _ in
                self?.toggleMode()
            }
        )
        .withCustomRangeHighlightColor()

        // more vertical tap area as button is only 30 points high
        selectButton.tapAreaInsets = UIEdgeInsets(top: -10, left: 0, bottom: -10, right: 0)

        sheetHeaderView.addSubview(selectButton)
        selectButton.snp.makeConstraints { make in
            make.centerY.equalTo(closeButton)
            make.trailing.equalTo(closeButton.snp.leading).offset(-8)
            make.height.equalTo(30)
        }
    }

    private func toggleMode() {
        mode = mode == .normal ? .select : .normal
        selectButton.setTitle(mode == .normal ? String(localized: "Select") : String(localized: "Cancel"),
                              for: .normal)
        selectedSections.removeAll()
        selectedUploads.removeAll()
        collectionView.reloadData()
        updateBulkActionsBottomBarVisibility()
        updateSelectedMediaCountLabel()
    }

    /// Toggle current section selection and marks all items with section selection
    private func toggleSectionAndAllItemsSelected(sectionIndex: Int) {
        let currentValue = selectedSections.contains(sectionIndex)
        let selected = !currentValue
        markSection(sectionIndex, selected: selected)

        // select/deselect all uploads in section
        guard let sectionId = dataSource.sectionIdentifier(for: sectionIndex) else { return }
        let itemsCount = dataSource.snapshot(for: sectionId).items.count
        let indexPaths = (0 ..< itemsCount).map { IndexPath(row: $0, section: sectionIndex) }
        for indexPath in indexPaths {
            markIndexPath(indexPath, selected: selected)
        }
    }

    /// Marks section as selected - adds/removes from selectedSections and updates the section header
    private func markSection(_ index: Int, selected: Bool) {
        let currentValue = selectedSections.contains(index)
        guard currentValue != selected else { return }
        let selected = !currentValue
        if selected {
            selectedSections.insert(index)
        } else {
            selectedSections.remove(index)
        }
        guard let headerView = collectionView.supplementaryView(
            forElementKind: UICollectionView.elementKindSectionHeader,
            at: IndexPath(item: 0, section: index)
        ) as? MediaCollectionViewHeader else { return }
        headerView.mark(selected: selected)
    }

    /// Returns `true` if all items in given section are selected
    private func allItemsSelected(inSection sectionIndex: Int) -> Bool {
        guard let sectionId = dataSource.sectionIdentifier(for: sectionIndex) else { return false }
        let itemsCount = dataSource.snapshot(for: sectionId).items.count
        let indexPaths = (0 ..< itemsCount).map { IndexPath(row: $0, section: sectionIndex) }
        return indexPaths
            .compactMap { dataSource.itemIdentifier(for: $0)?.upload.id ?? nil } // get upload ids
            .allSatisfy(selectedUploads.contains)
    }

    /// Toggle the selection for upload at given indexPath and update all relevant UI elements (toggle section, update bottom bar)
    private func toggleSelectionAndUpdateUI(forIndexPath indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        let selected = !selectedUploads.contains(item.id)
        markIndexPath(indexPath, selected: selected)
        if selected {
            // markSection selected if all uploads selected
            if allItemsSelected(inSection: indexPath.section) {
                markSection(indexPath.section, selected: true)
            }
        } else {
            markSection(indexPath.section, selected: false)
        }
        updateBulkActionsBottomBarVisibility()
        updateSelectedMediaCountLabel()
    }

    /// Marks the selected indexPath cell as selected and add/remove to selectedUploads
    private func markIndexPath(_ indexPath: IndexPath, selected: Bool) {
        guard let uploadId = dataSource.itemIdentifier(for: indexPath)?.upload.id else { return }
        if selected {
            selectedUploads.insert(uploadId)
        } else {
            selectedUploads.remove(uploadId)
        }
        if let cell = collectionView.cellForItem(at: indexPath) as? ImageMediaCollectionViewCell {
            cell.mark(selected: selected)
        } else if let cell = collectionView.cellForItem(at: indexPath) as? DocumentMediaCollectionViewCell {
            cell.mark(selected: selected)
        }
    }

    /// Recalculate section selection (new uploads might render the section unselected)
    /// newly added/removed sections might change the section indices
    private func reloadSelectedSections() {
        for sectionIndex in 0 ..< dataSource.numberOfSections(in: collectionView) {
            let sectionSelected = allItemsSelected(inSection: sectionIndex)
            markSection(sectionIndex, selected: sectionSelected)
        }
    }

    /// Called after uploads were updated, some uploads might be gone, so they're no longer selected
    private func reloadSelectedUploads() {
        let newUploads = Set<String>(filteredUploads.map(\.id))
        // Update the selectedUploads and remove all no longer existing uploads
        selectedUploads.formIntersection(newUploads)
    }

    /// Called when uploads or filters have changed
    private func reloadUploads(reloadCollectionView: Bool) {
        reloadSelectedUploads()
        dataSource.apply(prepareSnapshot(), animatingDifferences: false)
        if reloadCollectionView {
            collectionView.reloadData()
        }
        reloadSelectedSections()

        onUploadsChanged()
    }

    private func onUploadsChanged() {
        updateBulkActionsBottomBarVisibility()
        updateSelectedMediaCountLabel()
        updateFiltersIndicatorBadge()

        let emptyUploads = uploads.isEmpty
        let emptyFilteredUploads = filteredUploads.isEmpty

        mediaFiltersButton.isHidden = emptyUploads
        selectButton.isHidden = emptyUploads

        if emptyUploads {
            if emptyUploadsView == nil {
                emptyUploadsView = setupEmptyStateView(fromFilters: false)
                containerView.addSubview(emptyUploadsView!)
                emptyUploadsView!.snp.makeConstraints { make in
                    make.centerY.equalToSuperview()
                    make.leading.trailing.equalToSuperview()
                }
            }
        } else if emptyFilteredUploads {
            if emptyFilteredUploadsView == nil {
                emptyFilteredUploadsView = setupEmptyStateView(fromFilters: true)
                containerView.addSubview(emptyFilteredUploadsView!)
                emptyFilteredUploadsView!.snp.makeConstraints { make in
                    make.centerY.equalToSuperview()
                    make.leading.trailing.equalToSuperview()
                }
            }
        }
        emptyUploadsView?.isHidden = !emptyUploads
        emptyFilteredUploadsView?.isHidden = emptyUploads || !emptyFilteredUploads
    }

    /// Handle long press on cells - enabled select mode if not enabled and select given cell
    @objc func handleLongPress(gesture: UILongPressGestureRecognizer!) {
        guard gesture.state == .began else { return }

        let point = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }

        // enable select mode if in normal mode
        if mode == .normal {
            toggleMode()
        }
        // handle selection/deselection
        toggleSelectionAndUpdateUI(forIndexPath: indexPath)
    }
}

// MARK: - media filters

extension MediaCardViewController {
    private func setupMediaFiltersButton() {
        mediaFiltersButton.addTarget(self, action: #selector(showMediaFiltersCard), for: .touchUpInside)
        containerView.addSubview(mediaFiltersButton)
        mediaFiltersButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.bottom.equalTo(containerView.safeAreaLayoutGuide.snp.bottom).offset(-12)
        }
    }

    private func setupFiltersIndicatorBadge() {
        filtersIndicatorBadge.backgroundColor = .systemGreen
        filtersIndicatorBadge.contentInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        filtersIndicatorBadge.textColor = .Neutral_10
        filtersIndicatorBadge.font = .systemFont(ofSize: 11, weight: .bold)
        filtersIndicatorBadge.isUserInteractionEnabled = false
        mediaFiltersButton.addSubview(filtersIndicatorBadge)
        filtersIndicatorBadge.snp.makeConstraints { make in
            make.centerX.equalToSuperview().offset(16)
            make.centerY.equalToSuperview().offset(-16)
        }
    }

    @objc func showMediaFiltersCard() {
        let mediaFiltersCardVC = MediaFiltersCardViewController(model: projectModel, mediaFilters: mediaFilters)
        mediaFiltersCardVC.installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    @objc func mediaFiltersUpdated() {
        // reload uploads when filters change, no need to reload the collection view data as
        // this change is only about adding/removing cells (and not updating them)
        reloadUploads(reloadCollectionView: false)
    }

    private var filteredUploads: [Upload] {
        [Upload](uploads).filter(mediaFilters.match)
    }
}

// MARK: - bulk actions

extension MediaCardViewController {
    private func setupBulkActionsBottomBar() {
        guard bulkActionsBottomBar == nil else { return }
        let bottomBar = UIView()
        bottomBar.backgroundColor = .clear

        let blurEffect = UIBlurEffect(style: .regular)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.isUserInteractionEnabled = false
        bottomBar.addSubview(blurEffectView)
        blurEffectView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalToSuperview().offset(100) // add some for the bottom safe area
        }

        let stroke = UIView()
        stroke.backgroundColor = .dynamic(.Neutral_07)
        bottomBar.addSubview(stroke)
        stroke.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(1)
        }

        let countLabel = UILabel()
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.textColor = .dynamic(.Neutral_04)
        countLabel.font = ._preferredFont(forTextStyle: .subheadline, symbolicTraits: .traitBold)
        bottomBar.addSubview(countLabel)
        countLabel.snp.makeConstraints { make in
            make.centerY.equalTo(bottomBar.snp.top).offset(36)
            make.leading.equalToSuperview().inset(16)
        }

        let button = RangeButton(
            configuration: UIButton.Configuration.blueButton(),
            primaryAction: UIAction(
                image: UIImage(systemName: "ellipsis")
            ) { [weak self] _ in self?.showBulkActions() }
        ).withCustomRangeHighlightColor()

        bottomBar.addSubview(button)
        button.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview().inset(16)
            make.width.height.equalTo(40)
        }
        containerView.addSubview(bottomBar)
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(containerView.snp.bottom)
        }

        bulkActionsBottomBar = bottomBar
        bulkActionsButton = button
        selectedMediaCountLabel = countLabel
        containerView.layoutIfNeeded()
    }

    private func updateFiltersIndicatorBadge() {
        let filteredCount = filteredUploads.count
        // don't show the indicator if fitler is not impacting the visible uploads
        filtersIndicatorBadge.isHidden = filteredCount == uploads.count
        filtersIndicatorBadge.text = filteredCount >= 99 ? "99+" : String(filteredCount)
    }

    private func updateSelectedMediaCountLabel() {
        selectedMediaCountLabel?.text = selectedMediaCountText
    }

    var selectedMediaCountText: String {
        let numberOfItems = selectedUploads.count
        return (numberOfItems == 1)
            ? String(localized: "1x media item selected")
            : String(localized: "\(numberOfItems)x media items selected")
    }

    /// show or hide the bottom bar for bulk actions button
    private func updateBulkActionsBottomBarVisibility() {
        let shouldHide = selectedUploads.isEmpty
        if shouldHide {
            if let bottomBar = bulkActionsBottomBar {
                bottomBar.snp.remakeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.top.equalTo(bottomBar.superview!.snp.bottom)
                }
                mediaFiltersButton.snp.remakeConstraints { make in
                    make.trailing.equalToSuperview().inset(12)
                    make.bottom.equalTo(containerView.safeAreaLayoutGuide.snp.bottom).offset(-12)
                }
                UIView.animate(withDuration: 0.2) { [weak self] in
                    self?.containerView.layoutIfNeeded()
                }
            }
            collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            collectionView.scrollIndicatorInsets = collectionView.contentInset
        } else {
            setupBulkActionsBottomBar()
            if let bottomBar = bulkActionsBottomBar {
                bottomBar.snp.remakeConstraints { make in
                    make.leading.trailing.equalToSuperview()
                    make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
                }
                mediaFiltersButton.snp.remakeConstraints { make in
                    make.trailing.equalToSuperview().inset(12)
                    make.bottom.equalTo(bottomBar.snp.top).offset(-12)
                }
                UIView.animate(withDuration: 0.2) { [weak self] in
                    self?.containerView.layoutIfNeeded()
                } completion: { [weak self] _ in
                    guard let self = self else { return }
                    self.collectionView.contentInset = UIEdgeInsets(
                        top: 0,
                        left: 0,
                        bottom: bottomBar.frame.height,
                        right: 0
                    )
                    self.collectionView.scrollIndicatorInsets = self.collectionView.contentInset
                }
            }
        }
    }

    private func showBulkActions() {
        var actions: [ActionItem] = [
            ActionItem(title: String(localized: "Bulk Manage Tags"), imageName: "tag",
                       handler: { [weak self] in self?.presentBulkManageTagsCard() }),
            ActionItem(title: String(localized: "Share"), imageName: "square.and.arrow.up",
                       handler: { [weak self] in self?.shareMedia() }),
        ]

        // only show the Delete option if user has permissions to remove any of them
        let uploadsToDelete = uploads
            .filter { self.selectedUploads.contains($0.id) }
            .filter { self.projectModel.currentUser.canDelete($0) }
            .map(\.id)
        if !uploadsToDelete.isEmpty {
            actions.append(
                ActionItem(title: String(localized: "Delete Media"), imageName: "trash", style: .destructive,
                           handler: { [weak self] in
                               self?.confirmAndDeleteMedia([String](uploadsToDelete))
                           })
            )
        }

        ActionSelectorCardViewController(
            icon: UIImage(systemName: "ellipsis"),
            title: String(localized: "Bulk Actions"),
            subtitle: "(\(selectedMediaCountText))",
            actions: actions
        ).installAndShowCard(in: canvasContainer)
    }

    private func presentBulkManageTagsCard() {
        let tagsViewModel = TagsViewModel(model: projectModel)

        let addTagsOptionText = String(localized: "Add additional, new tags to the selected media items.")
        let replaceTagsOptionText = String(localized:
            "Replace ALL existing tags with new tags for the selected media items. ALL existing tags will be removed and replaced with new tags.")

        let tagsVC = SearchAndSelectTagsViewController(tagsViewModel: tagsViewModel, autoDismissCard: false)
        tagsVC.showCancelConfirmBottomBar = true
        tagsVC.showOptions(
            [ActionItem(title: String(localized: "Add Tags"), handler: { [weak tagsVC] in
                tagsVC?.setOptionLabel(addTagsOptionText)
            }),
            ActionItem(title: String(localized: "Replace Tags"), handler: { [weak tagsVC] in
                tagsVC?.setOptionLabel(replaceTagsOptionText)
            })]
        )
        tagsVC.setOptionLabel(addTagsOptionText)

        // block to run for confirming the changes and dismissing the card
        let onConfirm = { [weak self, weak tagsVC] in
            // add or replace depending on the option selected in tagsVC (adding is the first option)
            let addTags: Bool = (tagsVC?.optionsToggle?.selectedSegmentIndex ?? 0) == 0
            self?.updateTags(tagsViewModel, add: addTags)
            tagsVC?.dismissCard()
        }
        // block to run when user has unsaved changes and chose to close the card - ask if he wants to cancel or save
        let onUnsavedChanges = { [weak tagsVC] in
            guard let tagsVC = tagsVC else { return }
            // user selected some tags, confirm if closing should apply the changes
            let alertController = UIAlertController(
                title: "You have unsaved changes",
                message: "Would you like to confirm or cancel these changes?",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                tagsVC.dismissCard()
            })
            alertController.addAction(UIAlertAction(title: "Confirm", style: .default) { _ in
                onConfirm()
            })
            tagsVC.present(alertController, animated: true)
        }

        // when closing check if user selected any tasks and confirm if so
        tagsVC.onClose = { [weak tagsVC] in
            if tagsViewModel.selectedTags.isEmpty {
                tagsVC?.dismissCard()
            } else {
                onUnsavedChanges()
            }
        }
        // always dismiss on cancel
        tagsVC.onCancel = { [weak tagsVC] in tagsVC?.dismissCard() }
        // apply changes on confirm
        tagsVC.onConfirm = onConfirm

        tagsVC.installAndShowCard(in: canvasContainer, inView: canvasContainer.controls)
    }

    private func updateTags(_ tagsModel: TagsViewModel, add: Bool) {
        projectModel.run(
            projectModel.update(tags: tagsModel.selectedTags, forUploads: [String](selectedUploads), add: add)
        ) { error in
            if error != nil {
                ToastWindow.shared.showError(text: "Failed to update tags")
            }
        }
    }

    /// Fetch files for all selected uploads and use iOS built in activity view controller to share them.
    private func shareMedia() {
        let uploads = [Upload](uploads
            .filter { self.selectedUploads.contains($0.id) })

        UIApplication.shared.sendAction(
            #selector(ProjectFlowController.shareMediaAction), to: nil, from: self,
            for: FlowEvent(uploads, sourceView: bulkActionsButton)
        )
    }

    func confirmAndDeleteMedia(_ uploads: [String]) {
        ActionSelectorCardViewController(
            icon: nil,
            title: String(localized: "Are you sure?"),
            description: String(
                localized: "Careful! Selected media and any associated data will be deleted from this project permanently. This can't be undone!"
            ),
            actions: [
                ActionItem(
                    title: String(localized: "Delete Media"),
                    imageName: "trash", style: .destructive, handler: { [weak self] in
                        self?.deleteMedia(uploads)
                    }
                ),
                ActionItem(title: "Cancel", imageName: "xmark"),
            ]
        ).installAndShowCard(in: canvasContainer)
    }

    private func deleteMedia(_ uploads: [String]) {
        projectModel.run(projectModel.delete(uploads: uploads)) { [weak self] error in
            if error != nil {
                ToastWindow.shared.showError(text: "Failed to delete media")
            } else {
                ToastWindow.shared.showSuccess(text:
                    "\(uploads.count) media deleted successfully")
                // clear the selection and back to normal mode after all selected uploads were removed
                self?.toggleMode()
            }
        }
    }
}

extension MediaCardViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    /// Size the items so there are 3 items in a row
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        guard let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout else { return .zero }
        let availableWidth = collectionView.bounds.width - flowLayout.sectionInset.left - flowLayout.sectionInset.right

        guard let sectionId = dataSource.sectionIdentifier(for: indexPath.section) else { return .zero }
        let sectionUploads = dataSource.snapshot(for: sectionId).items
        guard indexPath.item < sectionUploads.count else { return .zero }
        let upload = sectionUploads[indexPath.item].upload

        if upload.isImage {
            let itemWidth = floor((availableWidth + flowLayout.minimumInteritemSpacing) / 3 - flowLayout
                .minimumInteritemSpacing)
            return CGSize(width: itemWidth, height: itemWidth)
        } else {
            return CGSize(width: availableWidth, height: 66)
        }
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

    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if mode == .normal {
            guard let upload = dataSource.itemIdentifier(for: indexPath)?.upload else { return }
            UIApplication.shared.sendAction(
                #selector(ProjectFlowActions.showFullscreenMediaAction),
                to: nil,
                from: self,
                for: FlowEvent(upload, source: .media)
            )
        } else {
            toggleSelectionAndUpdateUI(forIndexPath: indexPath)
        }
    }
}

// MARK: diffable data source

extension MediaCardViewController {
    func cell(forCollectionView collectionView: UICollectionView, indexPath: IndexPath,
              collectionItem: CollectionItem) -> UICollectionViewCell?
    {
        let upload = collectionItem.upload
        if upload.isImage {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell",
                                                          for: indexPath) as! ImageMediaCollectionViewCell
            cell.setUpload(upload, model: projectModel, imageDataProvider: imageProvider(forUpload: upload))
            cell.mark(selected: selectedUploads.contains(upload.id))
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "DocumentCell",
                                                          for: indexPath) as! DocumentMediaCollectionViewCell
            cell.setUpload(upload)
            cell.mark(selected: selectedUploads.contains(upload.id))
            return cell
        }
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
            headerView.mark(selected: mode == .normal ? nil : selectedSections.contains(indexPath.section))
            if mode == .select {
                headerView.addGestureRecognizer(UITapGestureRecognizer(
                    target: self, action: #selector(headerTapAction)
                ))
            } else {
                headerView.addGestureRecognizer(UILongPressGestureRecognizer(
                    target: self, action: #selector(headerLongPressAction)
                ))
            }
            return headerView
        }
        return nil
    }

    @objc private func headerTapAction(sender: UITapGestureRecognizer) {
        guard mode == .select else { return }
        guard
            let headerView = sender.view as? MediaCollectionViewHeader,
            // a little hack, the name displayed for the section is it's identifier
            let sectionIdentifier = headerView.label.text,
            let sectionIndex = dataSource.index(for: sectionIdentifier) else { return }
        toggleSectionAndAllItemsSelected(sectionIndex: sectionIndex)
        updateBulkActionsBottomBarVisibility()
        updateSelectedMediaCountLabel()
    }

    @objc private func headerLongPressAction(gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        guard
            let headerView = gesture.view as? MediaCollectionViewHeader,
            // a little hack, the name displayed for the section is it's identifier
            let sectionIdentifier = headerView.label.text,
            let sectionIndex = dataSource.index(for: sectionIdentifier) else { return }
        if mode == .normal {
            toggleMode()
        }
        toggleSectionAndAllItemsSelected(sectionIndex: sectionIndex)
        updateBulkActionsBottomBarVisibility()
        updateSelectedMediaCountLabel()
    }
}

// MARK: - Images prefetching

extension MediaCardViewController: UICollectionViewDataSourcePrefetching {
    /// map indexPath to CollectionItem from the current diffable data source snapshot and return the image provider for it's upload id
    func imageProvider(forItemAt indexPath: IndexPath) -> RangeImageDataProvider? {
        guard let sectionId = dataSource.sectionIdentifier(for: indexPath.section) else { return nil }
        let sectionUploads = dataSource.snapshot(for: sectionId).items
        guard indexPath.item < sectionUploads.count else { return nil }
        let upload = sectionUploads[indexPath.item].upload
        return imageProvider(forUpload: upload)
    }

    func imageProvider(forUpload upload: Upload) -> RangeImageDataProvider? {
        guard let mediaKey = MediaKey.autoAnnotatedMediaKey(
            projectId: projectModel.projectId,
            upload: upload,
            thumbnailNumber: 1
        ) else { return nil }

        return mediaCache.imageProvider(forKey: mediaKey)
    }

    func collectionView(_: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        guard indexPaths.count > 0 else { return }
        guard let firstImageDataProvider = imageProvider(forItemAt: indexPaths[0]) else { return }
        let sources = indexPaths
            .compactMap { imageProvider(forItemAt: $0) }
            .map { Source.provider($0) }
        ImagePrefetcher(sources: sources, options: firstImageDataProvider.options).start()
    }
}

extension MediaCardViewController {
    /// returns the empty state view for media card. There are 2 variants, if fromFilters=false it means that there's not uploads at all,
    /// if fromFilters=true it means that after filtering there's no uploads
    private func setupEmptyStateView(fromFilters: Bool) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let pin = UIImageView(image: UIImage(named: "large_media_pin"))
        view.addSubview(pin)
        pin.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
        }
        let titleLabel = UILabel()
        titleLabel.font = ._preferredFont(forTextStyle: .title3, symbolicTraits: .traitBold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .dynamic(.Neutral_04)
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.text = fromFilters
            ? String(localized: "There are no results...🤔")
            : String(localized: "It looks like there’s no media...🤔")
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(pin.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(36)
        }
        let descriptionLabel = UILabel()
        descriptionLabel.font = .preferredFont(forTextStyle: .body)
        descriptionLabel.adjustsFontForContentSizeCategory = true
        descriptionLabel.textColor = .dynamic(.Neutral_05)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center

        if fromFilters {
            // use attributed string to insert the filter icon
            let attributedText = NSMutableAttributedString(string: "Try adjusting your ")
            let filterImage = UIImage(systemName: "line.3.horizontal.decrease.circle") ?? UIImage()
            let filterAttachment = NSTextAttachment(image: filterImage)
            attributedText.append(NSAttributedString(attachment: filterAttachment))
            attributedText.append(NSAttributedString(string: " filters"))
            descriptionLabel.attributedText = attributedText
        } else {
            descriptionLabel.text = String(localized: "Add photos and documents to pins on the canvas")
        }

        view.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(36)
            make.bottom.equalToSuperview()
        }
        return view
    }
}
