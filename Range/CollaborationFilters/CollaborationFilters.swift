import Foundation
import RealmSwift

/// Defines Collaborations filters
class CollaborationFilters: Codable, Equatable {
    enum Variant: Codable {
        case taskList // fitlers with defaults for task list
        case canvas // filters with defaults for canvas
    }

    let variant: Variant

    /// The name for the notification posted in NotificationCenter when the filters change
    var updateNotificationName: Notification.Name {
        variant == .taskList
            ? Notification.Name("io.range.App.TaskListFiltersUpdated")
            : Notification.Name("io.range.App.CanvasFiltersUpdated")
    }

    enum AssigneeFilterType: CaseIterable, Codable {
        case onlyMine, everyone, select

        var displayName: String {
            switch self {
            case .onlyMine: return String(localized: "Only Mine")
            case .everyone: return String(localized: "Everyone")
            case .select: return String(localized: "Select")
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case variant,
             assigneeFilterType, assigneeFilter,
             showCreatedInLastNDays, showUpdatedInLastNDays,
             showPhotoCollaborations, showTasks, hiddenStatuses,
             showOnlyOverdue,
             canvasFilter,
             tagsFilter,
             followersFilter,
             identifiersFilter,
             showOnlyCreatedByUser,
             showArchived
    }

    weak var model: ProjectModel?

    /// 3 value toggle for enabling filtering by assignee
    var assigneeFilterType: AssigneeFilterType { didSet {
        if assigneeFilterType != oldValue {
            updateAssigneeFilter()
            postUpdate()
        }
    }}

    private func updateAssigneeFilter() {
        if assigneeFilterType == .onlyMine {
            // preselect current user
            if let currentUserId = model?.userId {
                assigneeFilter = [currentUserId]
            }
        } else {
            // for .everyone we don't want filters - it'll allow everyone
            // for .select we need to clear the filters as user will choose manually
            assigneeFilter = nil
        }
    }

    /// This is not nil when user enabled filtering by assignee.
    /// If not nil and not empty then only match the collaborations that have any of given assignees (or doesn't have assignee if filter
    /// contains a special UserViewModel.unassignedUserId)
    /// Achtung: it's private so it doesn't trigger the postUpdate, as it's updated in the TaskListFilters init. The setAssigneeFilter is a public
    /// method to change the assigneeFilter and trigger the update
    private(set) var assigneeFilter: [String]? = nil

    func setAssigneeFilter(_ assigneeFilter: [String]?) {
        self.assigneeFilter = assigneeFilter
        postUpdate()
    }

    /// When present only match collaborations created in the last n days.
    var showCreatedInLastNDays: Int? = nil { didSet { postUpdate() }}

    /// When present only match collaborations updated in the last n days.
    var showUpdatedInLastNDays: Int? = nil { didSet { postUpdate() }}

    /// Filter by canvas, if nil or empty then all canvases allowed
    var canvasFilter: [String]? = nil { didSet { postUpdate() }}

    /// Whether to show photo pins
    var showPhotoCollaborations: Bool = false { didSet { postUpdate() } }

    /// Whether to show tasks
    var showTasks: Bool = true { didSet { postUpdate() } }

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

    /// This is not nil when user enabled filtering by followers.
    /// If not nil and not empty then only match the collaborations that have any of given followers
    /// Achtung: it's private so it doesn't trigger the postUpdate, as it's updated in the TaskListFilters init. The setFollowersFilter is a public
    /// method to change the filter and trigger the update
    private(set) var followersFilter: [String]? = nil

    func setFollowersFilter(_ followersFilter: [String]?) {
        self.followersFilter = followersFilter
        postUpdate()
    }

    /// This is not nil when user enabled filtering by collaboration identifiers.
    /// If not nil and not empty then only match the collaborations that have given id (internal id, not the collaboration identifier, the
    /// collaboration identifier is only used for displaying at filters UI but at the end this filter specifies the exact ids)
    var identifiersFilter: [String]? = nil { didSet { postUpdate() }}

    /// Whether to show onlye the overdue tasks or all of them
    var showOnlyOverdue: Bool = false { didSet { postUpdate() } }

    /// Whether to show only the tasks created by the current user
    var showOnlyCreatedByUser: Bool = false { didSet { postUpdate() } }

    /// Whether to show archived tasks
    var showArchived: Bool = false { didSet { postUpdate() } }

    /// Use notification center to post the notification about update in filters
    private func postUpdate() {
        NotificationCenter.default.post(name: updateNotificationName, object: self)
    }

    init(model: ProjectModel?, variant: Variant) {
        self.model = model
        self.variant = variant
        assigneeFilterType = variant == .taskList ? .onlyMine : .select
        showPhotoCollaborations = variant == .taskList ? false : true
        updateAssigneeFilter() // the initial value depends on the current user in the model
    }

    /// All collaborations for given variant
    func allCollaborations(_ model: ProjectModel) -> [Collaboration] {
        if variant == .taskList {
            return Array(model.mainRealm.objects(Collaboration.self)
                .where { (c: Query<Collaboration>) -> Query<Bool> in
                    c.placeholder == false && c.status != nil // only tasks
                })
        } else {
            return model.currentCanvas.pins.compactMap(\.collaborations.first)
        }
    }

    /// Reset the filters to default values
    func resetToDefaults() {
        let defaults = CollaborationFilters(model: model, variant: variant)
        assigneeFilterType = defaults.assigneeFilterType
        assigneeFilter = defaults.assigneeFilter
        showCreatedInLastNDays = defaults.showCreatedInLastNDays
        showUpdatedInLastNDays = defaults.showUpdatedInLastNDays
        showPhotoCollaborations = defaults.showPhotoCollaborations
        showTasks = defaults.showTasks
        canvasFilter = defaults.canvasFilter
        hiddenStatuses = defaults.hiddenStatuses
        tagsFilter = defaults.tagsFilter
        followersFilter = defaults.followersFilter
        identifiersFilter = defaults.identifiersFilter
        showOnlyOverdue = defaults.showOnlyOverdue
        showOnlyCreatedByUser = defaults.showOnlyCreatedByUser
        showArchived = defaults.showArchived
        postUpdate()
    }

    static func == (lhs: CollaborationFilters, rhs: CollaborationFilters) -> Bool {
        if lhs.assigneeFilterType != rhs.assigneeFilterType { return false }
        if lhs.assigneeFilter != rhs.assigneeFilter { return false }
        if lhs.showCreatedInLastNDays != rhs.showCreatedInLastNDays { return false }
        if lhs.showUpdatedInLastNDays != rhs.showUpdatedInLastNDays { return false }
        if lhs.showPhotoCollaborations != rhs.showPhotoCollaborations { return false }
        if lhs.showTasks != rhs.showTasks { return false }
        if lhs.hiddenStatuses != rhs.hiddenStatuses { return false }
        if lhs.canvasFilter != rhs.canvasFilter { return false }
        if lhs.tagsFilter != rhs.tagsFilter { return false }
        if lhs.followersFilter != rhs.followersFilter { return false }
        if lhs.identifiersFilter != rhs.identifiersFilter { return false }
        if lhs.showOnlyOverdue != rhs.showOnlyOverdue { return false }
        if lhs.showOnlyCreatedByUser != rhs.showOnlyCreatedByUser { return false }
        if lhs.showArchived != rhs.showArchived { return false }
        return true
    }

    var hasDefaultValues: Bool {
        self == CollaborationFilters(model: model, variant: variant)
    }
}

/// Extension for TaskListFilters to check if given Collaboration matches the filters
extension CollaborationFilters {
    func match(_ collaboration: Collaboration) -> Bool {
        if !showArchived, collaboration.isArchived { return false }

        if let status = collaboration.status {
            // task filters
            if !showTasks { return false }
            if !show(status) { return false }
            if let assigneeFilter, !assigneeFilter.isEmpty {
                if !matchAssignee(assigneeFilter, collaboration: collaboration) { return false }
            }
            if showOnlyOverdue, !collaboration.isOverdue { return false }
        } else {
            // photo collaboration filters
            if !showPhotoCollaborations { return false }
        }

        if let showCreatedInLastNDays, !DateOptions.isTimestampInLastNDays(
            showCreatedInLastNDays,
            timestamp: collaboration.createdAt
        ) {
            return false
        }

        if let showUpdatedInLastNDays, !DateOptions.isTimestampInLastNDays(
            showUpdatedInLastNDays,
            timestamp: collaboration.lastUpdatedTimestamp
        ) {
            return false
        }

        if let canvasFilter, !canvasFilter.isEmpty {
            if !matchCanvas(canvasFilter, collaboration: collaboration) { return false }
        }

        if showOnlyCreatedByUser, collaboration.author?.id != model?.userId { return false }
        if let tagsFilter, !tagsFilter.isEmpty {
            if !matchTags(tagsFilter, collaboration: collaboration) { return false }
        }
        if let followersFilter, !followersFilter.isEmpty {
            if !matchFollowers(followersFilter, collaboration: collaboration) { return false }
        }
        if let identifiersFilter, !identifiersFilter.isEmpty {
            if !identifiersFilter.contains(collaboration.id) { return false }
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
            if collaboration.geometry.first?.canvas.first?.id == canvas { return true }
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

    /// Return `true` if collaboration.followers contain at least one follower from the followers filter
    func matchFollowers(_ followers: [String], collaboration: Collaboration) -> Bool {
        return collaboration.followers.contains(where: { followers.contains($0.id) })
    }
}
