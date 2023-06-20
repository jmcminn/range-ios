import Foundation

/// Defines filters for task list
class TaskListFilters: Codable, Equatable {
    /// The name for the notification posted in NotificationCenter when the filters change
    static let UpdateNotificationName = Notification.Name("io.range.App.TaskListFiltersUpdated")

    private enum CodingKeys: String, CodingKey {
        case hiddenStatuses, assigneeFilter, canvasFilter, tagsFilter, showOverdue, showOnlyCreatedByUser,
             showArchived
    }

    weak var model: ProjectModel?

    // TODO: 1292 only mine / everyone / select
    /// This is not nil when user enabled filtering by assignee.
    /// If not nil and not empty then only match the collaborations that have any of given assignees (or doesn't have assignee if filter
    /// contains a special UserViewModel.unassignedUserId)
    var assigneeFilter: [String]? = nil { didSet { postUpdate() }}

    /// Filter by canvas, if nil or empty then all canvases allowed
    var canvasFilter: [String]? = nil { didSet { postUpdate() }}

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
    /// If not nil and not empty then only match the collaborations that have (or their upload have) all of given tags (tag ids).
    var tagsFilter: [String]? = nil { didSet { postUpdate() }}

    /// Whether to show overdue tasks
    var showOverdue: Bool = true { didSet { postUpdate() } }

    /// Whether to show only the tasks created by the current user
    var showOnlyCreatedByUser: Bool = false { didSet { postUpdate() } }

    /// Whether to show archived tasks
    var showArchived: Bool = false { didSet { postUpdate() } }

    /// Use notification center to post the notification about update in filters
    private func postUpdate() {
        NotificationCenter.default.post(name: TaskListFilters.UpdateNotificationName, object: self)
    }

    /// Reset the filters to default values
    func resetToDefaults() {
        let defaults = TaskListFilters()
        assigneeFilter = defaults.assigneeFilter
        canvasFilter = defaults.canvasFilter
        hiddenStatuses = defaults.hiddenStatuses
        tagsFilter = defaults.tagsFilter
        showOverdue = defaults.showOverdue
        showOnlyCreatedByUser = defaults.showOnlyCreatedByUser
        showArchived = defaults.showArchived
        postUpdate()
    }

    static func == (lhs: TaskListFilters, rhs: TaskListFilters) -> Bool {
        if lhs.assigneeFilter != rhs.assigneeFilter { return false }
        if lhs.canvasFilter != rhs.canvasFilter { return false }
        if lhs.hiddenStatuses != rhs.hiddenStatuses { return false }
        if lhs.tagsFilter != rhs.tagsFilter { return false }
        if lhs.showOverdue != rhs.showOverdue { return false }
        if lhs.showOnlyCreatedByUser != rhs.showOnlyCreatedByUser { return false }
        if lhs.showArchived != rhs.showArchived { return false }
        return true
    }

    var hasDefaultValues: Bool {
        self == TaskListFilters()
    }
}

/// Extension for TaskListFilters to check if given Collaboration matches the filters
extension TaskListFilters {
    func match(_ collaboration: Collaboration) -> Bool {
        if !showArchived, collaboration.isArchived { return false }

        if let status = collaboration.status {
            // task filters
            if !show(status) { return false }
            if let assigneeFilter = assigneeFilter, !assigneeFilter.isEmpty {
                if !matchAssignee(assigneeFilter, collaboration: collaboration) { return false }
            }
        } else {
            // only show tasks
            return false
        }
        if let canvasFilter = canvasFilter, !canvasFilter.isEmpty {
            if !matchCanvas(canvasFilter, collaboration: collaboration) { return false }
        }

        if !showOverdue, collaboration.isOverdue { return false }
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

    /// Return `true` if the task is on one of given canvases
    func matchCanvas(_ canvases: [String], collaboration: Collaboration) -> Bool {
        for canvas in canvases {
            if collaboration.feature.first?.geometry.first?.canvas.first?.id == canvas { return true }
        }
        return false
    }

    /// Return `true` if all `tags` are in the collaboration or it's uploads tags. If tags is [untaggedId] then the collaboration matches
    /// if it's untagged (and all of its uploads are untagged)
    func matchTags(_ tags: [String], collaboration: Collaboration) -> Bool {
        var allCollaborationTags = Set<String>(collaboration.tags.map(\.id))
        for upload in collaboration.uploads {
            allCollaborationTags = allCollaborationTags.union(upload.tags.map(\.id))
        }

        if tags.first == TagViewModel.untaggedId {
            return allCollaborationTags.isEmpty
        }

        for tag in tags {
            if !allCollaborationTags.contains(tag) { return false }
        }

        return true
    }
}
