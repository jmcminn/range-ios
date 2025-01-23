import Foundation
import Knock
import OSLog

/// Knock model for currently logged in user
///
/// The implementation assumes that calls to all model methods are made on the main thread.
class KnockFeedModel {
    private static let inAppFeedId = "58be23cc-2ccd-48a5-87b5-7e9fcc175027"

    let client: KnockClient
    let feedOptions: Knock.FeedClientOptions
    var feedManager: Knock.FeedManager?

    // current feed
    @Published private(set) var feed: Knock.Feed = .init()

    // init feed model for given organization
    init(knockClient: KnockClient, organizationId: String) {
        client = knockClient
        feedOptions = .init(archived: .exclude, trigger_data: [
            "organizationId": AnyCodable(organizationId),
        ])
    }

    // init feed model for given project
    init(knockClient: KnockClient, projectId: String) {
        client = knockClient
        feedOptions = .init(archived: .exclude, trigger_data: [
            "projectId": AnyCodable(projectId),
        ])
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

    @MainActor
    private func _start() async throws {
        try await initializeFeedManager()
        loadPage(.initial)
    }

    /// (Re)initializes the feedManager.
    @MainActor
    private func initializeFeedManager() async throws {
        // disconnect the previous feedManager
        if let feedManager {
            feedManager.disconnectFromFeed()
        }
        feedManager = try await Knock.FeedManager(
            feedId: KnockFeedModel.inAppFeedId,
            options: feedOptions
        )
        feedManager?.connectToFeed()
        feedManager?.on(eventName: "new-message") { [weak self] _ in
            self?.loadPage(.before)
        }
    }

    func stop() {
        feedManager?.disconnectFromFeed()
    }

    /// Cleanup loaded data and reload the first page, so the state is as if it was just started
    func reset() {
        feed = .init()
        start()
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
    ///
    /// If the call to Knock API fails this function will reset the KnockClient (to obtain new user token) and try again. It'll only retry once.
    private func loadPage(_ pageToLoad: PageToLoad) {
        Task {
            await self.runActionAndResetRetryOnError("load page") {
                try await self._loadPage(pageToLoad)
            }
        }
    }

    /// Used by loadPage.
    /// To be retried on error.
    @MainActor
    private func _loadPage(_ pageToLoad: PageToLoad) async throws {
        var options = feedOptions
        switch pageToLoad {
        case .before: options.before = feed.page_info.before
        case .initial: break
        case .after: options.after = feed.page_info.after
        }
        guard let feed = try await feedManager?._getUserFeedContent(options: options) else {
            Logger.knock.error("Knock.FeedManager not initialized")
            return
        }
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
    }

    /// Marks all items configured for this model as seen.
    ///
    /// If the call to Knock API fails this function will reset the KnockClient (to obtain new user token) and try again. It'll only retry once.
    @MainActor
    func markAllSeen() async throws {
        await runActionAndResetRetryOnError("markAllSeen", action: _markAllSeen)
    }

    /// Used by `markAllSeen`
    /// To be retried on error.
    func _markAllSeen() async throws {
        guard feed.meta.unseen_count > 0 else { return }
        try await feedManager?._makeBulkStatusUpdate(type: .seen, options: feedOptions)
        // update the local state as the call to Knock API doesn't update the local results
        feed.meta.unseen_count = 0
    }

    /// Marks all items configured for this model as read.
    ///
    /// If the call to Knock API fails this function will reset the KnockClient (to obtain new user token) and try again. It'll only retry once.
    @MainActor
    func markAllRead() async throws {
        await runActionAndResetRetryOnError("markAllRead", action: _markAllRead)
    }

    /// Used by `markAllRead`
    /// To be retried on error.
    func _markAllRead() async throws {
        guard feed.meta.unread_count > 0 else { return }
        try await feedManager?._makeBulkStatusUpdate(type: .read, options: feedOptions)
        // update the local state as the call to Knock API doesn't update the local results
        feed.entries = feed.entries.map {
            var copy = $0
            copy.read_at = Date()
            return copy
        }
        feed.meta.unread_count = 0
    }

    /// Marks given item as read.
    ///
    /// If the call to Knock API fails this function will reset the KnockClient (to obtain new user token) and try again. It'll only retry once.
    func markRead(_ item: Knock.FeedItem) async throws {
        await runActionAndResetRetryOnError("markRead") {
            try await self._markRead(item)
        }
    }

    /// Used by `markRead`
    /// To be retried on error.
    func _markRead(_ item: Knock.FeedItem) async throws {
        let client = try await client.get()
        try await client._updateMessageStatus(messageId: item.id, status: .read)
        // update the local state as the call to Knock API doesn't update the local results
        if let itemIndex = feed.entries.firstIndex(where: { $0.id == item.id }) {
            feed.entries[itemIndex].read_at = Date()
        }
        feed.meta.unread_count = max(0, feed.meta.unread_count - 1)
    }

    /// Run given action. If it fails reset the KnockClient and reinitialize the feedManager and try again.
    /// - Parameters
    ///   - actionName: for error logging purposes
    ///   - action: the async action to run and retry on failure
    @MainActor
    private func runActionAndResetRetryOnError(
        _ actionName: String,
        action: @escaping () async throws -> Void
    ) async {
        do {
            try await action()
        } catch {
            Logger.knock.error("\(actionName) failed: \(error, privacy: .public)")
            // reset KnockClient
            client.reset()
            do {
                // also reset the feedManager...
                try await initializeFeedManager()
                // retry
                try await action()
            } catch {
                Logger.knock.error("\(actionName) retry failed: \(error, privacy: .public)")
            }
        }
    }
}
