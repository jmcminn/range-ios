import Foundation

/// Defines filters used when showing the pins on the canvas
/// The filters are projects specific (contain statuses, tags and user ids that are only valid for given project)
class CanvasFilters: Codable {
    /// The name for the notification posted in NotificationCenter when the filters change
    static let UpdateNotificationName = Notification.Name("io.range.App.CanvasFiltersUpdated")

//    var showPhotoPins: Bool = true
//    var showTaskPins: Bool = true
    var showArchivedPins: Bool = false { didSet {
        NotificationCenter.default.post(name: CanvasFilters.UpdateNotificationName, object: self)
    } }
}
