import Combine
import Foundation
import Knock
import OSLog
import UIKit

class InAppFeedCardViewController: SheetCardViewController {
    /// what to show in the feed
    private enum ViewMode {
        case all
        case unread
        case read
    }

    private var viewMode = ViewMode.all
    private var viewModeToggle: SegmentedControl!

    private let model: KnockFeedModel

    private var markAllAsReadButton: RangeButton!
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = UIView()

    /// combine observers
    private var subscriptions = Set<AnyCancellable>()

    init(model: KnockFeedModel) {
        self.model = model
        super.init(
            icon: UIImage(systemName: "bell"),
            title: String(localized: "Notifications")
        )

        model.$feed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                // mark all seen if the feed updates while user is looking at it
                self.markAllSeen()
                self.updateMarkAllAsReadButtonEnabled()
                self.updateEmptyViewHidden()
                self.tableView.reloadData()
            }
            .store(in: &subscriptions)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupMarkAllAsReadButton()
        setupViewModeToggle()

        addSheetHeaderStroke()
        addSheetHeaderShadowBasedOnDrivingScrollView()

        setupTableView()
        containerView.insertSubview(tableView, belowSubview: sheetHeaderView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        setupEmptyView()
        containerView.addSubview(emptyView)
        emptyView.snp.makeConstraints { make in
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }

        updateMarkAllAsReadButtonEnabled()
        updateEmptyViewHidden()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // we want to mark all seen when the feed is shown
        markAllSeen()
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        if cardPosition == .max {
            // just make it max, so it doesn't depend on the content height
            return Double.greatestFiniteMagnitude
        } else {
            return super.height(forContainer: cardContainerView, cardPosition: cardPosition)
        }
    }

    override func drivingScrollView() -> UIScrollView? {
        tableView
    }

    private func setupMarkAllAsReadButton() {
        guard markAllAsReadButton == nil else { return }
        var config = UIButton.Configuration.filled()
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        config.baseBackgroundColor = .dynamic(.Neutral_09)
        config.baseForegroundColor = .dynamic(.Neutral_04)
        config.cornerStyle = .fixed
        config.background.cornerRadius = 15
        config.background.strokeColor = .dynamic(.Neutral_07)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: .footnote)
            return outgoing
        }
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .caption2)
        config.imagePlacement = .trailing
        config.imagePadding = 4
        markAllAsReadButton = RangeButton(
            configuration: config,
            primaryAction: UIAction(
                title: String(localized: "Mark all as read"),
                image: UIImage(systemName: "checkmark.circle")
            ) { [weak self] _ in
                self?.model.markAllRead { error in
                    if let error {
                        Logger.knock.error("Failed to mark all in-app items as read: \(error, privacy: .public)")
                    }
                }
            }
        )
        .withCustomRangeHighlightColor()

        // more vertical tap area as button is only 30 points high
        markAllAsReadButton.tapAreaInsets = UIEdgeInsets(top: -10, left: 0, bottom: -10, right: 0)

        sheetHeaderView.addSubview(markAllAsReadButton)
        markAllAsReadButton.snp.makeConstraints { make in
            make.centerY.equalTo(closeButton)
            make.trailing.equalTo(closeButton.snp.leading).offset(-8)
            make.height.equalTo(30)
        }
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
        addSheetHeaderSubview(viewModeToggle)
        viewModeToggle.snp.makeConstraints { make in
            make.height.equalTo(SegmentedControl.height)
        }
    }

    private func setupTableView() {
        tableView.backgroundColor = view.backgroundColor
        tableView.sectionHeaderTopPadding = 0
        tableView.delegate = self
        tableView.dataSource = self
        tableView.prefetchDataSource = self
        tableView.separatorStyle = .none
        tableView.register(InAppFeedItemTableViewCell.self, forCellReuseIdentifier: "FeedItem")
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

    private func updateMarkAllAsReadButtonEnabled() {
        markAllAsReadButton.isEnabled = model.feed.meta.unread_count > 0
    }

    private func markAllSeen() {
        model.markAllSeen { error in
            if let error {
                Logger.knock.error("Failed to mark all in-app items as seen: \(error, privacy: .public)")
            }
        }
    }
}

extension InAppFeedCardViewController: UITableViewDelegate, UITableViewDataSource {
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
            withIdentifier: "FeedItem",
            for: indexPath
        ) as! InAppFeedItemTableViewCell
        if indexPath.row < itemsForCurrentMode().count {
            cell.setFeedItem(itemsForCurrentMode()[indexPath.row])
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row < itemsForCurrentMode().count {
            let feedItem = itemsForCurrentMode()[indexPath.row]
            model.markRead(feedItem) { error in
                if let error {
                    Logger.knock.error(
                        "Failed to mark feed item \(feedItem.id) as read: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
            // we need NSURL so we can send it using the responder chain (it's an objC level mechanism)
            if let url = feedItem.actionUrl as? NSURL {
                dismissCard()
                UIApplication.shared.sendAction(
                    #selector(ProjectsFlowController.showRoute), to: nil, from: self, for: FlowEvent(url)
                )
            }
        }
    }
}

extension InAppFeedCardViewController: UITableViewDataSourcePrefetching {
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
