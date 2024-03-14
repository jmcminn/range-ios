import Foundation
import Knock
import OSLog

/// Knock model for currently logged in user
class KnockFeedModel {
    private static var inAppFeedId = "58be23cc-2ccd-48a5-87b5-7e9fcc175027"

    let client: KnockClient
    let feedOptions: Knock.FeedManager.FeedClientOptions
    var feedManager: Knock.FeedManager?

    /// Background serial queue to perform Knock operations. Separate for each KnockFeedModel instance
    /// All Knock API operations are run on this queue to isolate and serialize changes to the feed
    private let knockQueue: DispatchQueue

    // current feed
    @Published private(set) var feed: Knock.Feed = .init()

    // init feed model for given organization
    init(knockClient: KnockClient, organizationId: String) {
        client = knockClient
        feedOptions = .init(archived: .exclude, trigger_data: [
            "organizationId": AnyCodable(organizationId),
        ])
        knockQueue = DispatchQueue(label: "knock-feed-queue-\(organizationId)")
    }

    // init feed model for given project
    init(knockClient: KnockClient, projectId: String) {
        client = knockClient
        feedOptions = .init(archived: .exclude, trigger_data: [
            "projectId": AnyCodable(projectId),
        ])
        knockQueue = DispatchQueue(label: "knock-feed-queue-\(projectId)")
    }

    func start() {
        Task {
            do {
                try await _start()
            } catch {
                Logger.knock.error("\(error.localizedDescription)")
            }
        }
    }

    private func _start() async throws {
        let knockClient = try await client.get()
        feedManager = Knock.FeedManager(
            client: knockClient,
            feedId: KnockFeedModel.inAppFeedId,
            options: feedOptions
        )
        feedManager?.connectToFeed()
        feedManager?.on(eventName: "new-message") { [weak self] _ in
            self?.loadPage(.before)
        }
        loadPage(.initial)
    }

    func stop() {
        feedManager?.disconnectFromFeed()
    }

    func loadNextPage() {
        loadPage(.after)
    }

    enum PageToLoad {
        case before // when loading content on "new-message" - loading items in front of the current entries
        case initial // loading initial entries
        case after // loading next page - after the current entries
    }

    /// Load a page after the last page loaded (if after is `true`) or before the first page loaded (if after is `false`)
    private func loadPage(_ pageToLoad: PageToLoad) {
        knockQueue.async { [weak self] in
            guard let self else { return }
            var options = self.feedOptions
            switch pageToLoad {
            case .before: options.before = self.feed.page_info.before
            case .initial: break
            case .after: options.after = self.feed.page_info.after
            }
            self.feedManager?.getUserFeedContent(options: options) { [weak self] result in
                guard let self else { return }
                switch result {
                case let .success(feed):
                    self.feed.meta = feed.meta
                    let entries = feed.entries.map { $0._withParsedBody() }

                    switch pageToLoad {
                    case .before:
                        self.feed.entries.insert(contentsOf: entries, at: 0)
                        // store the first cursor in the page_info, so next time we load the first page before this cursor
                        self.feed.page_info.before = entries.first?.__cursor
                    case .initial:
                        self.feed.entries.append(contentsOf: entries)
                        // for initial page set both cursors for page loading
                        self.feed.page_info.before = entries.first?.__cursor
                        self.feed.page_info.after = entries.last?.__cursor
                    case .after:
                        self.feed.entries.append(contentsOf: entries)
                        // store the last cursor in the page_info, so next time we load the next page after this cursor
                        self.feed.page_info.after = entries.last?.__cursor
                    }
                case let .failure(error):
                    // TODO: 2519 reset KnockClient
                    Logger.knock.error("Load page failed: \(error, privacy: .public)")
                }
            }
        }
    }

    func markAllSeen(_ completion: @escaping (Error?) -> Void) {
        knockQueue.async { [weak self] in
            guard let self else { return }
            guard self.feed.meta.unseen_count > 0 else { return }
            feedManager?.makeBulkStatusUpdate(
                type: .seen,
                options: feedOptions,
                completionHandler: { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success:
                        // update the local state as the call to Knock API doesn't update the local results
                        self.feed.meta.unseen_count = 0
                        completion(nil)
                    case let .failure(error):
                        // TODO: 2519 reset KnockClient
                        completion(error)
                    }
                }
            )
        }
    }

    func markAllRead(_ completion: @escaping (Error?) -> Void) {
        knockQueue.async { [weak self] in
            guard let self else { return }
            feedManager?.makeBulkStatusUpdate(
                type: .read,
                options: feedOptions,
                completionHandler: { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success:
                        // update the local state as the call to Knock API doesn't update the local results
                        self.feed.entries = self.feed.entries.map {
                            var copy = $0
                            copy.read_at = Date()
                            return copy
                        }
                        self.feed.meta.unread_count = 0
                    case let .failure(error):
                        // TODO: 2519 reset KnockClient
                        completion(error)
                    }
                }
            )
        }
    }

    func markRead(_ item: Knock.FeedItem, _ completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let client = try await self.client.get()
                knockQueue.async { [weak self] in
                    guard let self else { return }
                    client.updateMessageStatus(messageId: item.id, status: .read) { [weak self] result in
                        guard let self else { return }
                        switch result {
                        case .success:
                            // update the local state as the call to Knock API doesn't update the local results
                            if let itemIndex = self.feed.entries.firstIndex(where: { $0.id == item.id }) {
                                self.feed.entries[itemIndex].read_at = Date()
                            }
                            self.feed.meta.unread_count = max(0, self.feed.meta.unread_count - 1)
                            completion(nil)
                        case let .failure(error):
                            // TODO: 2519 reset KnockClient
                            completion(error)
                        }
                    }
                }
            } catch {
                completion(error)
            }
        }
    }
}
