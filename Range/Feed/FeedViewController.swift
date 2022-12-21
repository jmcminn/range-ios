import Foundation
import OSLog
import RealmSwift
import UIKit

/// Feed showing comments, updates and uploads. Most recent items are to the top.
/// It can be created for a Collaboration, in this case the collaboration created item is the last one.
class FeedViewController: UIViewController {
    private let distanceBetweenMajorRows = 32.0
    private let distanceBetweenMinorRows = 16.0

    /// Conform to hashable by checking id only, we don't want the objects being accessed for hashing as the diffable data source
    /// will need hash when computing the diff and the object may already be gone (if some upload was removed for example)
    struct FeedItem: Hashable, Comparable {
        var id: String
        var timestamp: Date
        var item: AnyObject
        // whether this is a major or minor feed item
        var isMajor: Bool

        init?(asCollaborationCreated collaboration: Collaboration) {
            guard collaboration.author != nil else { return nil }
            id = collaboration.id
            timestamp = collaboration.timestamp
            item = collaboration
            isMajor = true
        }

        init(_ item: Comment) {
            id = item.id
            timestamp = item.timestamp
            self.item = item
            isMajor = true
        }

        init(_ item: Upload) {
            id = item.id
            timestamp = item.timestamp
            self.item = item
            isMajor = true
        }

        /// This initializer needs project model to check the if the status is "isCompleted" if this is a status update (then it's a major update,
        /// otherwise minor)
        init(_ update: Update, projectModel: ProjectModel) {
            id = update.id
            timestamp = update.timestamp
            item = update
            if update.field == .statusName, let statusId = update.newValue.stringValue,
               let status = projectModel.mainRealm.object(ofType: Status.self, forPrimaryKey: statusId),
               status.isCompleted
            {
                isMajor = true
            } else {
                isMajor = false
            }
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: FeedViewController.FeedItem, rhs: FeedViewController.FeedItem) -> Bool {
            lhs.id == rhs.id
        }

        /// Comparable by timestamp so FeedItems can be sorted by timestamp
        static func < (lhs: FeedViewController.FeedItem, rhs: FeedViewController.FeedItem) -> Bool {
            lhs.timestamp < rhs.timestamp
        }
    }

    unowned let imageCaches: ImageCaches
    unowned let projectModel: ProjectModel
    let collaboration: Collaboration?
    let uploads: Results<Upload>?
    let comments: Results<Comment>?
    let updates: Results<Update>?
    var onFeedUpdated: (() -> Void)?

    let tableView: UITableView
    private var dataSource: UITableViewDiffableDataSource<String, FeedItem>?
    private(set) var items: [FeedItem] = []

    /// Vertical line shown along the items
    private var verticalLine: FeedVerticalLine!
    /// Observations installed to keep the vertical line y position and height in sync with cells
    private var observationsForVerticalLine = [NSKeyValueObservation]()
    /// Required for verticalLine to stop at the top of last row
    private var lastRowHeight = 0.0

    var showMoreUpdates = true {
        didSet {
            if showMoreUpdates != oldValue {
                /// change the level of detail for feed items, reload the snapshot
                dataSource?.apply(prepareSnapshot(), animatingDifferences: true)
            }
        }
    }

    private var uploadsNotificationToken: NotificationToken?
    private var uploadFeedItems = [FeedItem]()

    private var commentsNotificationToken: NotificationToken?
    private var commentFeedItems = [FeedItem]()

    private var updatesNotificationToken: NotificationToken?
    private var updateFeedItems = [FeedItem]()

    /// Initialize for the collaboration feed = show updates for given collaboration
    init(imageCaches: ImageCaches, projectModel: ProjectModel, collaboration: Collaboration) {
        self.imageCaches = imageCaches
        self.projectModel = projectModel
        self.collaboration = collaboration
        // convert collections to results
        uploads = collaboration.uploads.filter(NSPredicate(value: true))
        comments = collaboration.comments.filter(NSPredicate(value: true))
        updates = collaboration.updates.filter(NSPredicate(value: true))

        tableView = UITableView(frame: .zero, style: .plain)

        super.init(nibName: nil, bundle: nil)
    }

    /// Initialize for the comments feed = show given comments only
    init(imageCaches: ImageCaches, projectModel: ProjectModel, comments: Results<Comment>) {
        self.imageCaches = imageCaches
        self.projectModel = projectModel
        collaboration = nil
        uploads = nil
        self.comments = comments
        updates = nil
        tableView = UITableView(frame: .zero, style: .plain)

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        uploadsNotificationToken?.invalidate()
        commentsNotificationToken?.invalidate()
        updatesNotificationToken?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)

        setupTableView()
        view.addSubview(tableView)

        setupVerticalLine()

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        observeUploads()
        observeComments()
        observeUpdates()
    }

    func scroll(toUpload upload: Upload) {
        if let indexPath = dataSource?.indexPath(for: FeedItem(upload)) {
            tableView.scrollToRow(at: indexPath, at: .top, animated: true)
        }
    }

    private func setupTableView() {
        tableView.backgroundColor = view.backgroundColor
        tableView.sectionHeaderTopPadding = 0
        tableView.estimatedRowHeight = 350
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.register(CollaborationCreatedFeedItemCell.self, forCellReuseIdentifier: "CollaborationCreated")
        tableView.register(ImageUploadFeedItemCell.self, forCellReuseIdentifier: "ImageUpload")
        tableView.register(CommentFeedItemCell.self, forCellReuseIdentifier: "Comment")
        tableView.register(NameUpdateFeedItemCell.self, forCellReuseIdentifier: "NameUpdate")
        tableView.register(StatusUpdateFeedItemCell.self, forCellReuseIdentifier: "StatusUpdate")
        tableView.register(CompletedStatusUpdateFeedItemCell.self, forCellReuseIdentifier: "CompletedStatusUpdate")
        tableView.register(AssigneeUpdateFeedItemCell.self, forCellReuseIdentifier: "AssigneeUpdate")
        tableView.register(DueDateUpdateFeedItemCell.self, forCellReuseIdentifier: "DueDateUpdate")

        // since each section has it's top header, the last one is added as a table footer
        tableView.tableFooterView =
            UIView(frame: CGRect(origin: .zero, size: CGSize(width: 100, height: distanceBetweenMajorRows)))
        tableView.tableFooterView?.backgroundColor = tableView.backgroundColor

        dataSource = UITableViewDiffableDataSource(
            tableView: tableView,
            cellProvider: { [weak self] tableView, indexPath, feedItem in
                self?.cell(forTableView: tableView, indexPath: indexPath, feedItem: feedItem)
            }
        )
    }

    private func setupVerticalLine() {
        // the y and height don't matter, they'll get synced with the content anyway
        verticalLine = FeedVerticalLine(frame: CGRect(
            origin: CGPoint(x: FeedItemCells.leadingVerticalLineMargin - 0.5, y: 0),
            size: CGSize(width: 1, height: 1)
        ))
        verticalLine.layer.zPosition = -1
        tableView.addSubview(verticalLine)
    }

    /// Update vertical line height based on content size and last row height
    private func updateVerticalLineHeight() {
        // - distanceBetweenMajorRows because it's a table footer view included in the content size
        // - lastRowHeight + 8 because for last row the vertical line should only reach the avatar/dot
        verticalLine.frame.size.height = max(
            tableView.contentSize.height - distanceBetweenMajorRows - lastRowHeight + 8
                - verticalLine.frame.origin.y, 0
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // observe header view size and table view content size to start the vertical line
        // below header and extend until the end of the content (excluding last cell, as it should
        // stop once it reaches the last cell's avatar/dot view)
        if let headerView = tableView.tableHeaderView {
            observationsForVerticalLine.append(
                headerView.observe(\.frame, changeHandler: { [weak self] _, _ in
                    guard let self = self else { return }
                    let verticalLineY = headerView.frame
                        .maxY + self.distanceBetweenMinorRows + 8 // +8 to start below the avatar or dot view
                    self.verticalLine.frame.origin.y = verticalLineY
                    self.updateVerticalLineHeight()
                })
            )
        } else {
            verticalLine.frame.origin.y = distanceBetweenMinorRows + 8
            updateVerticalLineHeight()
        }
        observationsForVerticalLine.append(
            tableView.observe(\.contentSize, changeHandler: { [weak self] _, _ in
                guard let self = self else { return }
                // we need to keep track of last cell size when the contentSize changes (it might have been just removed)
                // note: calling cellForRow is not actually allowed here as contentSize changes while table view
                // does the layout... so doing dispatch async is a little hack to get rid of the warnings
                DispatchQueue.main.async {
                    if let lastCell = self.tableView.cellForRow(at: IndexPath(row: 0, section: self.items.count - 1)) {
                        self.lastRowHeight = lastCell.frame.height
                    }
                    self.updateVerticalLineHeight()
                }
            })
        )
        observationsForVerticalLine.append(
            tableView.observe(\.contentOffset, changeHandler: { [weak self] _, _ in
                guard let self = self else { return }
                // we need to keep track of last cell size when the contentOffset changes (so user scrolled to it without contentSize change)
                // note: calling cellForRow is not actually allowed here as contentSize changes while table view
                // does the layout... so doing dispatch async is a little hack to get rid of the warnings
                DispatchQueue.main.async {
                    if let lastCell = self.tableView.cellForRow(at: IndexPath(row: 0, section: self.items.count - 1)) {
                        self.lastRowHeight = lastCell.frame.height
                        self.updateVerticalLineHeight()
                    }
                }
            })
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        observationsForVerticalLine.forEach { $0.invalidate() }
        observationsForVerticalLine.removeAll()
    }

    private func observeUploads() {
        guard let uploads = uploads else { return }
        uploadsNotificationToken = uploads
            .where { $0.placeholder == false && $0.fileType == .image }
            .sorted(by: \Upload.timestamp, ascending: DebugSettings().feedSortedAscendingByTimestamp)
            .observe { [weak self] change in
                guard let self = self else { return }
                switch change {
                case let .initial(uploads):
                    self.uploadFeedItems = [FeedItem](uploads.map { FeedItem($0) })
                    self.dataSource?.apply(self.prepareSnapshot(), animatingDifferences: false)

                case let .update(uploads, deletions: deletions, insertions: insertions, modifications: modifications):
                    if !deletions.isEmpty || !insertions.isEmpty {
                        // if there are some deletetions or insertions just apply the new snapshot
                        self.uploadFeedItems = [FeedItem](uploads.map { FeedItem($0) })
                        self.dataSource?.apply(self.prepareSnapshot(), animatingDifferences: true)
                    } else if !modifications.isEmpty {
                        // for modifications only reconfigure the modified items (the cells don't listen
                        // for updates).
                        let modifiedFeedItems: [FeedItem] = modifications.compactMap { index in
                            guard index < self.uploadFeedItems.count else { return nil }
                            return self.uploadFeedItems[index]
                        }
                        var snapshot = self.dataSource!.snapshot()
                        snapshot.reconfigureItems(modifiedFeedItems)
                        self.uploadFeedItems = [FeedItem](uploads.map { FeedItem($0) })
                        self.dataSource!.apply(snapshot, animatingDifferences: false)
                    }
                case .error: break
                }
            }
    }

    private func observeComments() {
        guard let comments = comments else { return }
        commentsNotificationToken = comments
            .where { $0.placeholder == false }
            .sorted(by: \Comment.timestamp, ascending: DebugSettings().feedSortedAscendingByTimestamp)
            .observe { [weak self] change in
                guard let self = self else { return }
                switch change {
                case let .initial(comments):
                    self.commentFeedItems = [FeedItem](comments.map { FeedItem($0) })
                    self.dataSource?.apply(self.prepareSnapshot(), animatingDifferences: false)
                case let .update(comments, deletions, insertions, modifications):
                    if !deletions.isEmpty || !insertions.isEmpty {
                        // if there are some deletetions or insertions just apply the new snapshot
                        self.commentFeedItems = [FeedItem](comments.map { FeedItem($0) })
                        self.dataSource?.apply(self.prepareSnapshot(), animatingDifferences: true)
                    } else if !modifications.isEmpty {
                        // for modifications only reconfigure the modified items (the cells don't listen
                        // for updates).
                        let modifiedFeedItems: [FeedItem] = modifications.compactMap { index in
                            guard index < self.commentFeedItems.count else { return nil }
                            return self.commentFeedItems[index]
                        }
                        var snapshot = self.dataSource!.snapshot()
                        snapshot.reconfigureItems(modifiedFeedItems)
                        // no animations as the animation for comment update (showing/hiding the completed)
                        // causes some weird effects
                        self.commentFeedItems = [FeedItem](comments.map { FeedItem($0) })
                        self.dataSource!.apply(snapshot, animatingDifferences: false)
                    }
                case .error: break
                }
            }
    }

    private func observeUpdates() {
        guard let updates = updates else { return }
        updatesNotificationToken = updates
            .where {
                $0.placeholder == false &&
                    ($0.field == .name || $0.field == .description || $0.field == .statusName ||
                        $0.field == .assignee || $0.field == .dueDateTimestamp)
            }
            .sorted(by: \Update.timestamp, ascending: DebugSettings().feedSortedAscendingByTimestamp)
            .observe { [weak self] change in
                guard let self = self else { return }
                switch change {
                case let .initial(updates):
                    self.updateFeedItems = [FeedItem](updates.map { FeedItem($0, projectModel: self.projectModel) })
                    self.dataSource?.apply(self.prepareSnapshot(), animatingDifferences: false)

                case let .update(updates, deletions: _, insertions: _, modifications: _):
                    self.updateFeedItems = [FeedItem](updates.map { FeedItem($0, projectModel: self.projectModel) })
                    self.dataSource?.apply(self.prepareSnapshot(), animatingDifferences: true)
                case .error: break
                }
            }
    }

    /// Prepare new snapshot for the diffable data source
    /// Add all items sorted by timestamp and include Collaboration for 'collaboration created'
    private func prepareSnapshot() -> NSDiffableDataSourceSnapshot<String, FeedItem> {
        let ascending = DebugSettings().feedSortedAscendingByTimestamp
        var items = _mergeSortedArrays(FeedItem.self, commentFeedItems, uploadFeedItems, ascending: ascending)

        if showMoreUpdates {
            // add all updatesFeedItems
            items = _mergeSortedArrays(FeedItem.self, items, updateFeedItems, ascending: ascending)
        } else {
            // add only major
            let majorUpdateFeedItems = updateFeedItems.filter(\.isMajor)
            items = _mergeSortedArrays(FeedItem.self, items, majorUpdateFeedItems, ascending: ascending)
        }

        /// Add 'collaboration created' feed item
        if let collaboration = collaboration, let createdFeedItem = FeedItem(asCollaborationCreated: collaboration) {
            if ascending {
                // if ascending then 'created' first and items after
                items.insert(createdFeedItem, at: 0)
            } else {
                // descending - items first and created last
                items.append(createdFeedItem)
            }
        }

        var snapshot = NSDiffableDataSourceSnapshot<String, FeedItem>()
        // each feed item has its own section as it's easy to control cells spacing with section
        // header and footer height
        items.forEach { item in
            snapshot.appendSections([item.id])
            snapshot.appendItems([item], toSection: item.id)
        }
        self.items = items
        onFeedUpdated?()
        return snapshot
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        // update the colors
        tableView.reloadData()
    }
}

// MARK: table view delegate

extension FeedViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            // there's already some padding at the top
            return distanceBetweenMinorRows
        }
        // minor spacing is only between 2 minor cells. Any other combination gets major spacing
        if section < items.count, !items[section].isMajor, !items[section - 1].isMajor {
            return distanceBetweenMinorRows
        }
        return distanceBetweenMajorRows
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.section < items.count else { return }
        guard let upload = items[indexPath.section].item as? Upload else { return }
        UIApplication.shared.sendAction(
            #selector(ProjectFlowActions.showFullscreenMediaAction),
            to: nil,
            from: self,
            for: FlowEvent(upload)
        )
    }

    func tableView(_: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        UIView()
    }
}

// MARK: table view diffable data source

extension FeedViewController {
    func cell(forTableView tableView: UITableView, indexPath: IndexPath, feedItem: FeedItem) -> UITableViewCell? {
        if let collaboration = feedItem.item as? Collaboration {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CollaborationCreated",
                                                     for: indexPath) as! CollaborationCreatedFeedItemCell
            cell.set(collaboration: collaboration)
            return cell
        } else if let upload = feedItem.item as? Upload, upload.fileType == .image {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ImageUpload",
                                                     for: indexPath) as! ImageUploadFeedItemCell
            let imageCacheKey = uploadKey(projectId: projectModel.projectId, uploadId: upload.id, thumbnailNumber: 1)
            cell.imageDataProvider = imageCaches.imageProvider(forPhotoWithCacheKey: imageCacheKey)
            cell.set(upload: upload, model: projectModel)
            return cell
        } else if let comment = feedItem.item as? Comment {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Comment",
                                                     for: indexPath) as! CommentFeedItemCell
            cell.set(comment: comment, model: projectModel)
            return cell
        } else if let update = feedItem.item as? Update, update.field == .name || update.field == .description {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NameUpdate",
                                                     for: indexPath) as! NameUpdateFeedItemCell
            cell.tableView = tableView
            cell.set(update: update)
            return cell
        } else if let update = feedItem.item as? Update, update.field == .statusName,
                  let statusId = update.newValue.stringValue,
                  let status = projectModel.mainRealm.object(ofType: Status.self, forPrimaryKey: statusId)
        {
            if status.isCompleted {
                let cell = tableView.dequeueReusableCell(withIdentifier: "CompletedStatusUpdate",
                                                         for: indexPath) as! CompletedStatusUpdateFeedItemCell
                cell.set(update: update, status: status)
                return cell

            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "StatusUpdate",
                                                         for: indexPath) as! StatusUpdateFeedItemCell
                cell.set(update: update, status: status)
                return cell
            }
        } else if let update = feedItem.item as? Update, update.field == .assignee {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AssigneeUpdate",
                                                     for: indexPath) as! AssigneeUpdateFeedItemCell
            let oldAssignee = projectModel.mainRealm.object(
                ofType: Participant.self,
                forPrimaryKey: update.oldValue.stringValue ?? ""
            )
            let newAssignee = projectModel.mainRealm.object(
                ofType: Participant.self,
                forPrimaryKey: update.newValue.stringValue ?? ""
            )
            cell.set(update: update, oldAssignee: oldAssignee, newAssignee: newAssignee)
            return cell
        } else if let update = feedItem.item as? Update, update.field == .dueDateTimestamp {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DueDateUpdate",
                                                     for: indexPath) as! DueDateUpdateFeedItemCell
            cell.set(update: update, timeZone: projectModel.projectSummary.timeZone)
            return cell
        }
        return nil
    }
}
