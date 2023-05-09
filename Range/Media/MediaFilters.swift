import Foundation

/// Defines filters used when showing the uploads in Media card
class MediaFilters: Equatable {
    /// The name for the notification posted in NotificationCenter when the filters change
    static let UpdateNotificationName = Notification.Name("io.range.App.MediaFiltersUpdated")

    /// Defines possible values for media type filter
    enum MediaTypeFilter {
        case all, photos, documents
    }

    /// whether to show all media or only photos or documents
    var mediaTypeFilter: MediaTypeFilter = .all { didSet { postUpdate() }}

    /// This is not nil when user enabled filtering by author.
    /// If not nil and not empty then only match the uploads that have any of given authors
    var authorFilter: [String]? { didSet { postUpdate() }}

    /// This is not nil when user enabled filtering by tags.
    /// If not nil and not empty then only match the uploads that have all of given tags (tag ids).
    var tagsFilter: [String]? { didSet { postUpdate() }}

    /// Use notification center to post the notification about update in filters
    private func postUpdate() {
        NotificationCenter.default.post(name: MediaFilters.UpdateNotificationName, object: self)
    }

    /// Reset the filters to default values
    func resetToDefaults() {
        let defaults = MediaFilters()
        mediaTypeFilter = defaults.mediaTypeFilter
        authorFilter = defaults.authorFilter
        tagsFilter = defaults.tagsFilter
        postUpdate()
    }

    static func == (lhs: MediaFilters, rhs: MediaFilters) -> Bool {
        if lhs.mediaTypeFilter != rhs.mediaTypeFilter { return false }
        if lhs.authorFilter != rhs.authorFilter { return false }
        if lhs.tagsFilter != rhs.tagsFilter { return false }
        return true
    }

    var hasDefaultValues: Bool {
        self == MediaFilters()
    }
}

/// Extension for MediaFilters to check if given Upload matches the filters
extension MediaFilters {
    func match(_ upload: Upload) -> Bool {
        if mediaTypeFilter == .photos, !upload.isImage { return false }
        if mediaTypeFilter == .documents, upload.isImage { return false }

        if let authorFilter = authorFilter, !authorFilter.isEmpty {
            if !matchAuthor(authorFilter, upload: upload) { return false }
        }
        if let tagsFilter = tagsFilter, !tagsFilter.isEmpty {
            if !matchTags(tagsFilter, upload: upload) { return false }
        }
        return true
    }

    /// Return `true` if the upload's author is one of given users.
    func matchAuthor(_ users: [String], upload: Upload) -> Bool {
        for user in users {
            if upload.author?.id == user { return true }
        }
        return false
    }

    /// Return `true` if all `tags` are in the upload. If tags is [untaggedId] then the upload matches if it's untagged
    func matchTags(_ tags: [String], upload: Upload) -> Bool {
        let uploadTags = Set<String>(upload.tags.map(\.id))

        if tags.first == TagViewModel.untaggedId {
            return uploadTags.isEmpty
        }

        for tag in tags {
            if !uploadTags.contains(tag) { return false }
        }

        return true
    }
}
