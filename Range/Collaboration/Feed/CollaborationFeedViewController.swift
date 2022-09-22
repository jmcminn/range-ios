import Foundation
import OSLog
import RealmSwift
import UIKit

/// Feed for the collaboration. Most recent items are to the top. Collaboration created item is the last one.
class CollaborationFeedViewController: UIViewController {
    /// Conform to hashable by checking id only, we don't want the objects being accessed for hashing as the diffable data source
    /// will need hash when computing the diff and the object may already be gone (if some upload was removed for example)
    struct FeedItem: Hashable {
        var id: String
        var item: AnyObject
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: CollaborationFeedViewController.FeedItem,
                        rhs: CollaborationFeedViewController.FeedItem) -> Bool
        {
            lhs.id == rhs.id
        }
    }

    unowned let imageCaches: ImageCaches
    unowned let projectModel: ProjectModel
    let collaboration: Collaboration

    let tableView: UITableView
    var dataSource: UITableViewDiffableDataSource<Int, FeedItem>!

    private var uploads: Results<Upload>!
    private var uploadsNotificationToken: NotificationToken?

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

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .dynamicColor(light: .Neutral_02, dark: .Neutral_09)

        setupTableView()
        view.addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        observeUploads()
        dataSource.apply(prepareSnapshot(), animatingDifferences: false)
    }

    func scroll(toUpload upload: Upload) {
        if let indexPath = dataSource.indexPath(for: FeedItem(id: upload.id, item: upload)) {
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
            .sorted(by: \Upload.timestamp, ascending: false)
        uploadsNotificationToken = uploads.observe { [weak self] _ in
            guard let self = self else { return }
            self.dataSource.apply(self.prepareSnapshot(), animatingDifferences: true)
        }
    }

    /// Prepare new snapshot for the diffable data source
    /// Add all items sorted by timestamp and include Collaboration for 'collaboration created'
    private func prepareSnapshot() -> NSDiffableDataSourceSnapshot<Int, FeedItem> {
        var snapshot = NSDiffableDataSourceSnapshot<Int, FeedItem>()
        snapshot.appendSections([1])
        snapshot.appendItems(uploads.map { FeedItem(id: $0.id, item: $0) })
        if collaboration.timestamp != nil, collaboration.author != nil {
            snapshot.appendItems([FeedItem(id: collaboration.id, item: collaboration)])
        }
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
        }
        return nil
    }
}
