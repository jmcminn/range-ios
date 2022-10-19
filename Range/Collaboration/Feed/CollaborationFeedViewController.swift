import Foundation
import OSLog
import RealmSwift
import UIKit

/// Feed for the collaboration. Most recent items are to the top. Collaboration created item is the last one.
class CollaborationFeedViewController: UIViewController {
    static let distanceBetweenRows = 32.0

    /// Conform to hashable by checking id only, we don't want the objects being accessed for hashing as the diffable data source
    /// will need hash when computing the diff and the object may already be gone (if some upload was removed for example)
    struct FeedItem: Hashable, Comparable {
        var id: String
        var timestamp: TimeInterval
        var item: AnyObject
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: CollaborationFeedViewController.FeedItem,
                        rhs: CollaborationFeedViewController.FeedItem) -> Bool
        {
            lhs.id == rhs.id
        }

        /// Comparable by timestamp so FeedItems can be sorted by timestamp
        static func < (lhs: CollaborationFeedViewController.FeedItem,
                       rhs: CollaborationFeedViewController.FeedItem) -> Bool
        {
            lhs.timestamp < rhs.timestamp
        }
    }

    unowned let imageCaches: ImageCaches
    unowned let projectModel: ProjectModel
    let collaboration: Collaboration

    let tableView: UITableView
    var dataSource: UITableViewDiffableDataSource<Int, FeedItem>?

    var showMoreUpdates = true {
        didSet {
            if showMoreUpdates != oldValue {
                /// change the level of detail for feed items, reload the snapshot
                dataSource?.apply(prepareSnapshot(), animatingDifferences: true)
            }
        }
    }

    private var uploads: Results<Upload>!
    private var uploadsNotificationToken: NotificationToken?

    private var comments: Results<Comment>!
    private var commentsNotificationToken: NotificationToken?

    private var updates: Results<Update>!
    private var updatesNotificationToken: NotificationToken?

    init(imageCaches: ImageCaches, projectModel: ProjectModel, collaboration: Collaboration) {
        self.imageCaches = imageCaches
        self.projectModel = projectModel
        self.collaboration = collaboration
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

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        observeUploads()
        observeComments()
        observeUpdates()
        dataSource?.apply(prepareSnapshot(), animatingDifferences: false)
    }

    func scroll(toUpload upload: Upload) {
        if let indexPath = dataSource?
            .indexPath(for: FeedItem(id: upload.id, timestamp: upload.timestamp, item: upload))
        {
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

        tableView.tableFooterView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 100, height: 4)))
        tableView.tableFooterView?.backgroundColor = tableView.backgroundColor

        dataSource = UITableViewDiffableDataSource(
            tableView: tableView,
            cellProvider: { [weak self] tableView, indexPath, feedItem in
                self?.cell(forTableView: tableView, indexPath: indexPath, feedItem: feedItem)
            }
        )
    }

    private func observeUploads() {
        uploads = collaboration.uploads
            .where { $0.placeholder == false && $0.fileType == .image
            }
            .sorted(by: \Upload.timestamp, ascending: DebugSettings().feedSortedAscendingByTimestamp)
        uploadsNotificationToken = uploads.observe { [weak self] _ in
            guard let self = self else { return }
            self.dataSource?.apply(self.prepareSnapshot(), animatingDifferences: true)
        }
    }

    private func observeComments() {
        comments = collaboration.comments
            .where { $0.placeholder == false }
            .sorted(by: \Comment.timestamp, ascending: DebugSettings().feedSortedAscendingByTimestamp)
        commentsNotificationToken = comments.observe { [weak self] _ in
            guard let self = self else { return }
            self.dataSource?.apply(self.prepareSnapshot(), animatingDifferences: true)
        }
    }

    private func observeUpdates() {
        updates = collaboration.updates
            .where {
                $0.placeholder == false &&
                    ($0.field == .name || $0.field == .description || $0.field == .statusName ||
                        $0.field == .assignee || $0.field == .dueDateTimestamp)
            }
            .sorted(by: \Update.timestamp, ascending: DebugSettings().feedSortedAscendingByTimestamp)
        updatesNotificationToken = updates.observe { [weak self] _ in
            guard let self = self else { return }
            self.dataSource?.apply(self.prepareSnapshot(), animatingDifferences: true)
        }
    }

    /// Prepare new snapshot for the diffable data source
    /// Add all items sorted by timestamp and include Collaboration for 'collaboration created'
    private func prepareSnapshot() -> NSDiffableDataSourceSnapshot<Int, FeedItem> {
        let ascending = DebugSettings().feedSortedAscendingByTimestamp
        var snapshot = NSDiffableDataSourceSnapshot<Int, FeedItem>()
        snapshot.appendSections([1])
        let commentFeedItems = [FeedItem](comments.map { FeedItem(id: $0.id, timestamp: $0.timestamp, item: $0) })
        let uploadFeedItems = [FeedItem](uploads.map { FeedItem(id: $0.id, timestamp: $0.timestamp, item: $0) })
        var items = _mergeSortedArrays(FeedItem.self, commentFeedItems, uploadFeedItems, ascending: ascending)
        if showMoreUpdates {
            let updatesFeedItems = [FeedItem](updates.map { FeedItem(id: $0.id, timestamp: $0.timestamp, item: $0) })
            items = _mergeSortedArrays(FeedItem.self, items, updatesFeedItems, ascending: ascending)
        } else {
            // only show the feed item for status update to completed...
            let updatesFeedItems = [FeedItem](updates
                .filter {
                    if $0.field == .statusName, let statusId = $0.newValue.stringValue,
                       let status = self.projectModel.mainRealm.object(ofType: Status.self, forPrimaryKey: statusId),
                       status.isCompleted
                    {
                        return true
                    }
                    return false
                }
                .map { FeedItem(id: $0.id, timestamp: $0.timestamp, item: $0) })
            items = _mergeSortedArrays(FeedItem.self, items, updatesFeedItems, ascending: ascending)
        }

        // not ascending then items first and created last
        if !ascending { snapshot.appendItems(items) }
        if let timestamp = collaboration.timestamp, collaboration.author != nil {
            snapshot.appendItems([FeedItem(id: collaboration.id, timestamp: timestamp, item: collaboration)])
        }
        // if ascending then 'created' first and items after
        if ascending { snapshot.appendItems(items) }

        return snapshot
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
        // update the colors
        tableView.reloadData()
    }
}

// MARK: table view delegate

extension CollaborationFeedViewController: UITableViewDelegate {}

// MARK: table view diffable data source

extension CollaborationFeedViewController {
    func cell(forTableView tableView: UITableView, indexPath: IndexPath, feedItem: FeedItem) -> UITableViewCell? {
        if let collaboration = feedItem.item as? Collaboration {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CollaborationCreated",
                                                     for: indexPath) as! CollaborationCreatedFeedItemCell
            cell.collaboration = collaboration
            return cell
        } else if let upload = feedItem.item as? Upload, upload.fileType == .image {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ImageUpload",
                                                     for: indexPath) as! ImageUploadFeedItemCell
            cell.imageCaches = imageCaches
            cell.projectModel = projectModel
            cell.tableView = tableView
            cell.upload = upload
            return cell
        } else if let comment = feedItem.item as? Comment {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Comment",
                                                     for: indexPath) as! CommentFeedItemCell
            cell.tableView = tableView
            cell.comment = comment
            return cell
        } else if let update = feedItem.item as? Update, update.field == .name || update.field == .description {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NameUpdate",
                                                     for: indexPath) as! NameUpdateFeedItemCell
            cell.tableView = tableView
            cell.update = update
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
            cell.set(update: update)
            return cell
        }
        return nil
    }
}
