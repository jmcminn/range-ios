import Foundation

/// Defines filters used when showing the pins on the canvas
/// The filters are projects specific (contain statuses, tags and user ids that are only valid for given project)
class CanvasFilters: Codable {
    /// The name for the notification posted in NotificationCenter when the filters change
    static let UpdateNotificationName = Notification.Name("io.range.App.CanvasFiltersUpdated")

    var showPhotoPins: Bool = true {
        didSet { NotificationCenter.default.post(name: CanvasFilters.UpdateNotificationName, object: self) }
    }

    var showTaskPins: Bool = true {
        didSet { NotificationCenter.default.post(name: CanvasFilters.UpdateNotificationName, object: self) }
    }

    var showArchivedPins: Bool = false {
        didSet { NotificationCenter.default.post(name: CanvasFilters.UpdateNotificationName, object: self) }
    }
}

/// Extension for CanvasFilters to check if given Collaboration matches the filters
extension CanvasFilters {
    func match(_ collaboration: Collaboration) -> Bool {
        if !showArchivedPins, collaboration.isArchived { return false }
        if !showPhotoPins, collaboration.status == nil { return false }
        if !showTaskPins, collaboration.status != nil { return false }
        return true
    }
}
