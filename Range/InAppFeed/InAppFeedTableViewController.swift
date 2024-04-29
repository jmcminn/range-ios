import Combine
import Foundation
import Knock
import OSLog
import UIKit

/// A view controller showing the in-app feed and handling the toggling between the different ViewModes
/// The toggle is not added to this VC as it's presentation depends on the parent VC (whether it's a card or "normal" view controller)
class InAppFeedTableViewController: UIViewController {
    /// what to show in the feed
    private enum ViewMode {
        case all
        case unread
        case read
    }

    private var viewMode = ViewMode.all
    private(set) var viewModeToggle: SegmentedControl!

    let model: KnockFeedModel
    private let variant: InAppFeedItemTableViewCell.Variant
    let avatarImageProvider: (String) -> UIImage?

    let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = UIView()

    /// combine observers
    private var subscriptions = Set<AnyCancellable>()

    var onItemSelected: ((Knock.FeedItem) -> Void)?

    init(
        model: KnockFeedModel,
        variant: InAppFeedItemTableViewCell.Variant,
        avatarImageProvider: @escaping (String) -> UIImage?
    ) {
        self.model = model
        self.variant = variant
        self.avatarImageProvider = avatarImageProvider
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViewModeToggle()

        setupTableView()
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        setupEmptyView()
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
        }

        updateEmptyViewHidden()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // we want to mark all seen when the feed is shown
        markAllSeen()
        model.$feed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                // mark all seen if the feed updates while user is looking at it
                self.markAllSeen()
                self.updateEmptyViewHidden()
                self.tableView.reloadData()
            }
            .store(in: &subscriptions)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        subscriptions.removeAll()
    }

    private func setupViewModeToggle() {
        viewModeToggle = SegmentedControl(items: [
            ActionItem(title: String(localized: "All"),
                       handler: { [weak self] in
                           self?.viewMode = .all
                           self?.tableView.reloadData()
                           self?.updateEmptyViewHidden()
                       }),
            ActionItem(title: String(localized: "Unread"),
                       handler: { [weak self] in
                           self?.viewMode = .unread
                           self?.tableView.reloadData()
                           self?.updateEmptyViewHidden()
                       }),
            ActionItem(title: String(localized: "Read"),
                       handler: { [weak self] in
                           self?.viewMode = .read
                           self?.tableView.reloadData()
                           self?.updateEmptyViewHidden()
                       }),
        ])
    }

    private func setupTableView() {
        tableView.backgroundColor = view.backgroundColor
        tableView.sectionHeaderTopPadding = 0
        tableView.delegate = self
        tableView.dataSource = self
        tableView.prefetchDataSource = self
        tableView.separatorStyle = .none
        tableView.register(InAppFeedItemTableViewCell.self, forCellReuseIdentifier: variant.rawValue)
        tableView.keyboardDismissMode = .onDrag
    }

    private func setupEmptyView() {
        let label1 = UILabel()
        label1.font = ._preferredFont(forTextStyle: .callout, symbolicTraits: .traitBold)
        label1.textColor = .dynamic(.Neutral_04)
        label1.adjustsFontForContentSizeCategory = true
        label1.numberOfLines = 0
        label1.textAlignment = .center
        label1.text = "No notifications yet"

        let label2 = UILabel()
        label2.font = .preferredFont(forTextStyle: .subheadline)
        label2.textColor = .dynamic(.Neutral_05)
        label2.adjustsFontForContentSizeCategory = true
        label2.numberOfLines = 0
        label2.textAlignment = .center
        label2.text = "We’ll let you know when we’ve got something new for you"

        emptyView.addSubview(label1)
        label1.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(64)
            make.leading.trailing.equalToSuperview().inset(32)
        }
        emptyView.addSubview(label2)
        label2.snp.makeConstraints { make in
            make.top.equalTo(label1.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(32)
            make.bottom.equalToSuperview().inset(64)
        }
    }

    private func updateEmptyViewHidden() {
        emptyView.isHidden = !itemsForCurrentMode().isEmpty
    }

    func markAllSeen() {
        Task {
            do {
                try await model.markAllSeen()
            } catch {
                Logger.knock.error("Failed to mark all in-app items as seen: \(error, privacy: .public)")
            }
        }
    }

    func markAllRead() {
        Task {
            do {
                try await model.markAllRead()
            } catch {
                Logger.knock.error("Failed to mark all in-app items as read: \(error, privacy: .public)")
            }
        }
    }

    func markRead(_ feedItem: Knock.FeedItem) {
        Task {
            do {
                try await model.markRead(feedItem)
            } catch {
                Logger.knock.error(
                    "Failed to mark feed item \(feedItem.id) as read: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}

extension InAppFeedTableViewController: UITableViewDelegate, UITableViewDataSource {
    func itemsForCurrentMode() -> [Knock.FeedItem] {
        switch viewMode {
        case .all: model.feed.entries
        case .unread: model.feed.entries.filter { $0.read_at == nil }
        case .read: model.feed.entries.filter { $0.read_at != nil }
        }
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        itemsForCurrentMode().count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: variant.rawValue,
            for: indexPath
        ) as! InAppFeedItemTableViewCell
        if indexPath.row < itemsForCurrentMode().count {
            let item = itemsForCurrentMode()[indexPath.row]
            let firstAvatarImage = item.actors?.map(\.id).compactMap { self.avatarImageProvider($0) }.first
            cell.setFeedItem(item, avatarImage: firstAvatarImage)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row < itemsForCurrentMode().count {
            let feedItem = itemsForCurrentMode()[indexPath.row]
            markRead(feedItem)

            // we need NSURL so we can send it using the responder chain (it's an objC level mechanism)
            if let url = feedItem.actionUrl as? NSURL {
                onItemSelected?(feedItem)
                UIApplication.shared.sendAction(
                    #selector(ProjectsFlowController.showRoute), to: nil, from: self, for: FlowEvent(url)
                )
            }
        }
    }
}

extension InAppFeedTableViewController: UITableViewDataSourcePrefetching {
    func tableView(_: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        guard !indexPaths.isEmpty else { return }
        // there's still something to load
        guard model.feed.meta.total_count > model.feed.entries.count else { return }
        let maxIndex = indexPaths.map(\.row).max()
        if maxIndex == itemsForCurrentMode().count - 1 {
            // asked to prefetch last row, load next page
            model.loadNextPage()
        }
    }
}
