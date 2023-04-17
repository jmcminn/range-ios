import Foundation

/// Defines filters used when showing the pins on the canvas
/// The filters are projects specific (contain statuses, tags and user ids that are only valid for given project)
class CanvasFilters: Codable {
    /// The name for the notification posted in NotificationCenter when the filters change
    static let UpdateNotificationName = Notification.Name("io.range.App.CanvasFiltersUpdated")

    private enum CodingKeys: String, CodingKey {
        case showPhotoPins, showTaskPins, hiddenStatuses, tagsFilter, showOnlyCreatedByUser, showArchivedPins
    }

    weak var model: ProjectModel?

    /// Whether to show photo pins
    var showPhotoPins: Bool = true { didSet { postUpdate() } }

    /// Whether to show task pins
    var showTaskPins: Bool = true { didSet { postUpdate() } }

    /// Keep the hidden status (and not shown) so if new status is added it is shown by default
    private var hiddenStatuses = Set<String>()

    /// Set given status as shown or hidden
    func set(_ status: Status, shown: Bool) {
        if shown {
            hiddenStatuses.remove(status.id)
        } else {
            hiddenStatuses.insert(status.id)
        }
        postUpdate()
    }

    /// Return if given status is shown
    func show(_ status: Status) -> Bool {
        !hiddenStatuses.contains(status.id)
    }

    /// This is not nil when user enabled filtering by tags.
    /// If not nil and not empty then only match the collaborations that have (or their upload have) any of given tags (tag ids).
    var tagsFilter: [String]? = nil { didSet { postUpdate() }}

    /// Whether to show only the pins created by the current user
    var showOnlyCreatedByUser: Bool = false { didSet { postUpdate() } }

    /// Whether to show archived pins
    var showArchivedPins: Bool = false { didSet { postUpdate() } }

    /// Use notification center to post the notification about update in filters
    private func postUpdate() {
        NotificationCenter.default.post(name: CanvasFilters.UpdateNotificationName, object: self)
    }
}

/// Extension for CanvasFilters to check if given Collaboration matches the filters
extension CanvasFilters {
    func match(_ collaboration: Collaboration) -> Bool {
        if !showArchivedPins, collaboration.isArchived { return false }
        if !showPhotoPins, collaboration.status == nil { return false }
        if !showTaskPins, collaboration.status != nil { return false }
        if let status = collaboration.status, !show(status) { return false }
        if showOnlyCreatedByUser, collaboration.author?.id != model?.userId { return false }
        if let tagsFilter = tagsFilter, !tagsFilter.isEmpty {
            if !matchTags(tagsFilter, collaboration: collaboration) { return false }
        }
        return true
    }

    /// Return `true` if at least 1 tag from `tags` is in the collaboration or it's uploads tags
    func matchTags(_ tags: [String], collaboration: Collaboration) -> Bool {
        var allCollaborationTags = Set<String>(collaboration.tags.map(\.id))
        for upload in collaboration.uploads {
            allCollaborationTags = allCollaborationTags.union(upload.tags.map(\.id))
        }

        for tag in tags {
            if allCollaborationTags.contains(tag) { return true }
        }

        return false
    }
}
