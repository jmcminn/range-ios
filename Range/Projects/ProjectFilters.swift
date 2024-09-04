import Foundation

/// Defines filters used when showing the projects listing
class ProjectFilters: Codable, Equatable {
    /// The name for the notification posted in NotificationCenter when the filters change
    static let UpdateNotificationName = Notification.Name("io.range.App.ProjectFiltersUpdated")
    
    private enum CodingKeys: String, CodingKey {
        case projectStateFilter
    }


    /// Defines possible values for project state
    enum ProjectStateFilter: CaseIterable, Codable {
        case all, active, archived

        var displayName: String {
            switch self {
            case .all: return String(localized: "All")
            case .active: return String(localized: "Active")
            case .archived: return String(localized: "Archived")
            }
        }
    }

    /// whether to show all projects or only active or archved
    var projectStateFilter: ProjectStateFilter = .all { didSet { postUpdate() }}

    /// Use notification center to post the notification about update in filters
    private func postUpdate() {
        NotificationCenter.default.post(name: ProjectFilters.UpdateNotificationName, object: self)
    }

    /// Reset the filters to default values
    func resetToDefaults() {
        let defaults = ProjectFilters()
        projectStateFilter = defaults.projectStateFilter
        postUpdate()
    }

    static func == (lhs: ProjectFilters, rhs: ProjectFilters) -> Bool {
        if lhs.projectStateFilter != rhs.projectStateFilter { return false }
        return true
    }

    var hasDefaultValues: Bool {
        self == ProjectFilters()
    }
}

/// Extension for ProjectFilters to check if given Project matches the filters
extension ProjectFilters {
    func match(_ project: ProjectSummary) -> Bool {
        if projectStateFilter == .active, project.isArchived { return false }
        if projectStateFilter == .archived, !project.isArchived { return false }
        return true
    }
}
