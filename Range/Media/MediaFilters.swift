import Foundation

/// Defines filters used when showing the uploads in Media card
class MediaFilters: Equatable {
    /// The name for the notification posted in NotificationCenter when the filters change
    static let UpdateNotificationName = Notification.Name("io.range.App.MediaFiltersUpdated")

    /// Defines possible values for media type filter
    enum MediaTypeFilter: CaseIterable {
        case all, photos, documents

        var displayName: String {
            switch self {
            case .all: return String(localized: "All Media")
            case .photos: return String(localized: "Photos")
            case .documents: return String(localized: "Documents")
            }
        }
    }

    /// whether to show all media or only photos or documents
    var mediaTypeFilter: MediaTypeFilter = .all { didSet { postUpdate() }}

    /// If not nil then match Uploads with timestamp `>=` given date (this will be set to the beginning of the day, so it's inclusive)
    private(set) var fromDate: Date? { didSet { postUpdate() }}

    /// If not nil then match Uploads with timestamp `<=` given date (this will be set to the end of the day, so it's inclusive)
    private(set) var toDate: Date? { didSet { postUpdate() }}

    /// This is not nil when user enabled filtering by author.
    /// If not nil and not empty then only match the uploads that have any of given authors
    var authorFilter: [String]? { didSet { postUpdate() }}

    /// This is not nil when user enabled filtering by tags.
    /// If not nil and not empty then only match the uploads that have all of given tags (tag ids).
    var tagsFilter: [String]? { didSet { postUpdate() }}

    /// Filter by canvas, if nil or empty then all canvases allowed
    var canvasFilter: [String]? { didSet { postUpdate() }}

    /// Use notification center to post the notification about update in filters
    private func postUpdate() {
        NotificationCenter.default.post(name: MediaFilters.UpdateNotificationName, object: self)
    }

    /// Set from date. Any time component is removed to use the beginning of a day (we want the fromDate to be inclusive in filters)
    func setFromDate(_ date: Date?) {
        if let date = date {
            fromDate = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: date)
        } else {
            fromDate = nil
        }
    }

    /// Set to date. Time is set to end of a day (we want the toDate to be inclusive in filters)
    func setToDate(_ date: Date?) {
        if let date = date {
            toDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: date)
        } else {
            toDate = nil
        }
    }

    /// Reset the filters to default values
    func resetToDefaults() {
        let defaults = MediaFilters()
        mediaTypeFilter = defaults.mediaTypeFilter
        fromDate = defaults.fromDate
        toDate = defaults.toDate
        authorFilter = defaults.authorFilter
        tagsFilter = defaults.tagsFilter
        canvasFilter = defaults.canvasFilter
        postUpdate()
    }

    static func == (lhs: MediaFilters, rhs: MediaFilters) -> Bool {
        if lhs.mediaTypeFilter != rhs.mediaTypeFilter { return false }
        if lhs.fromDate != rhs.fromDate { return false }
        if lhs.toDate != rhs.toDate { return false }
        if lhs.authorFilter != rhs.authorFilter { return false }
        if lhs.tagsFilter != rhs.tagsFilter { return false }
        if lhs.canvasFilter != rhs.canvasFilter { return false }
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

        if let fromDate = fromDate, upload.createdAt < fromDate { return false }
        if let toDate = toDate, upload.createdAt > toDate { return false }

        if let authorFilter = authorFilter, !authorFilter.isEmpty {
            if !matchAuthor(authorFilter, upload: upload) { return false }
        }
        if let tagsFilter = tagsFilter, !tagsFilter.isEmpty {
            if !matchTags(tagsFilter, upload: upload) { return false }
        }
        if let canvasFilter = canvasFilter, !canvasFilter.isEmpty {
            if !matchCanvas(canvasFilter, upload: upload) { return false }
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

    /// Return `true` if the upload belongs to a collaboration on one of given canvases
    func matchCanvas(_ canvases: [String], upload: Upload) -> Bool {
        for canvas in canvases {
            if upload.collaboration.first?.geometry.first?.canvas.first?.id == canvas {
                return true
            }
        }
        return false
    }
}
