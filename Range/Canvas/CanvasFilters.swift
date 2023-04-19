import Foundation

/// Defines filters used when showing the pins on the canvas
/// The filters are projects specific (contain statuses, tags and user ids that are only valid for given project)
class CanvasFilters: Codable, Equatable {
    /// The name for the notification posted in NotificationCenter when the filters change
    static let UpdateNotificationName = Notification.Name("io.range.App.CanvasFiltersUpdated")

    private enum CodingKeys: String, CodingKey {
        case showPhotoPins, showTaskPins, hiddenStatuses, assigneeFilter, tagsFilter, showOnlyCreatedByUser,
             showArchivedPins
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

    /// This is not nil when user enabled filtering by assignee.
    /// If not nil and not empty then only match the collaborations that have any of given assignees (or doesn't have assignee if filter
    /// contains a special UserViewModel.unassignedUserId)
    var assigneeFilter: [String]? = nil { didSet { postUpdate() }}

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

    /// Reset the filters to default values
    func resetToDefaults() {
        let defaults = CanvasFilters()
        showPhotoPins = defaults.showPhotoPins
        showTaskPins = defaults.showTaskPins
        hiddenStatuses = defaults.hiddenStatuses
        assigneeFilter = defaults.assigneeFilter
        tagsFilter = defaults.tagsFilter
        showOnlyCreatedByUser = defaults.showOnlyCreatedByUser
        showArchivedPins = defaults.showArchivedPins
        postUpdate()
    }

    static func == (lhs: CanvasFilters, rhs: CanvasFilters) -> Bool {
        if lhs.showPhotoPins != rhs.showPhotoPins { return false }
        if lhs.showTaskPins != rhs.showTaskPins { return false }
        if lhs.hiddenStatuses != rhs.hiddenStatuses { return false }
        if lhs.assigneeFilter != rhs.assigneeFilter { return false }
        if lhs.tagsFilter != rhs.tagsFilter { return false }
        if lhs.showOnlyCreatedByUser != rhs.showOnlyCreatedByUser { return false }
        if lhs.showArchivedPins != rhs.showArchivedPins { return false }
        return true
    }

    var hasDefaultValues: Bool {
        self == CanvasFilters()
    }
}

/// Extension for CanvasFilters to check if given Collaboration matches the filters
extension CanvasFilters {
    func match(_ collaboration: Collaboration) -> Bool {
        if !showArchivedPins, collaboration.isArchived { return false }

        if let status = collaboration.status {
            // task pin filters
            if !showTaskPins { return false }
            if !show(status) { return false }
            if let assigneeFilter = assigneeFilter, !assigneeFilter.isEmpty {
                if !matchAssignee(assigneeFilter, collaboration: collaboration) { return false }
            }
        } else {
            // photo pin filters
            if !showPhotoPins { return false }
        }

        if showOnlyCreatedByUser, collaboration.author?.id != model?.userId { return false }
        if let tagsFilter = tagsFilter, !tagsFilter.isEmpty {
            if !matchTags(tagsFilter, collaboration: collaboration) { return false }
        }
        return true
    }

    /// Return `true` if the task is assigned to one of given users. If the users is [unnassignedUserId] then
    /// the task matches if it's unassigned
    func matchAssignee(_ users: [String], collaboration: Collaboration) -> Bool {
        if users.first == UserViewModel.unassignedUserId {
            return collaboration.assignee == nil
        }
        for user in users {
            if collaboration.assignee?.id == user { return true }
        }
        return false
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
