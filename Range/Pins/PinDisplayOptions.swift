import Foundation
import MapboxMaps

/// Stores image and layout options for the pin
/// This is a universal description, independent of the pin rendering - whether it's Mapbox annotations or view annotations - they
/// configure the pins using different set of flags (with same meaning, but not using same struct)
struct PinDisplayOptions {
    /// the image to display for the pin
    var pinImage: PinImage
    /// the pin view alpha
    var alpha: CGFloat
    /// describes how to place the pin relatively to the point geometry
    var anchor: ViewAnnotationAnchor
    /// the offset for the pin relative to the point geometry, see ``ViewAnnotationOptions`` for more docs
    var offsetY: CGFloat
}

/// Type alias for function that given collaboration and whether this pin is selected and any pin is selected returns the pin display options
typealias GeometryPinDisplayOptionsProvider = (
    _ collaboration: Collaboration,
    _ selected: Bool,
    _ anythingSelected: Bool
) -> PinDisplayOptions

extension PinDisplayOptions {
    /// offset for pins (not circles) the distance between the image bottom and the tip of the pin
    static let pinYOffset = -4.0

    /// Display options for copy pin (copy task or photo)
    static func copyPinDisplayOptions() -> PinDisplayOptions {
        PinDisplayOptions(pinImage: .copyPin, alpha: 1, anchor: .bottom, offsetY: pinYOffset)
    }

    /// pin display options provider for regular display of pins
    static func regularPinDisplayOptionsProvider(collaboration: Collaboration, selected: Bool,
                                                 anythingSelected: Bool) -> PinDisplayOptions
    {
        // optional category, also nil for the default (=unassigned)
        let category = (collaboration.category?.isDefault ?? true) ? nil : collaboration.category
        let archived = collaboration.isArchived
        let uploadsCount = collaboration.uploads.count
        let overdue = collaboration.isOverdue
        let hasUncompletedNotes = collaboration.hasUncompletedNotes
        if selected {
            let pinImage: PinImage
            // TODO: support request for upload update
            if let status = collaboration.status {
                if archived {
                    // archived overrides any other rules
                    pinImage = .pinArchivedTask(category: category)
                } else if status.isCompleted {
                    // completed status doesn't care about overdue or notes
                    pinImage = .pinTask(color: status.color, category: category)
                } else {
                    pinImage = overdue
                        ? .pinTaskWithOverdue(color: status.color, category: category)
                        : (hasUncompletedNotes
                            ? .pinTaskWithNote(color: status.color, category: category)
                            : .pinTask(color: status.color, category: category))
                }
            } else {
                if archived {
                    pinImage = .pinArchivedPhoto(count: uploadsCount, category: category)
                } else {
                    pinImage = hasUncompletedNotes
                        ? .pinPhotoWithNote(count: uploadsCount, category: category)
                        : .pinPhoto(count: uploadsCount, category: category)
                }
            }
            return PinDisplayOptions(
                pinImage: pinImage,
                alpha: 1,
                anchor: .bottom,
                offsetY: PinDisplayOptions.pinYOffset
            )
        } else {
            let pinImage: PinImage
            if archived {
                // archived overrides any other rules
                if collaboration.status != nil {
                    pinImage = .circleArchivedTask(category: category)
                } else {
                    pinImage = .circleArchivedPhoto(count: uploadsCount, category: category)
                }
            } else if let status = collaboration.status, status.isCompleted {
                // completed status doesn't care about overdue or notes
                pinImage = .circleTask(color: status.color, category: category)
            } else if overdue {
                pinImage = .circleOverdue
            } else if hasUncompletedNotes {
                pinImage = .circleNote
            } else if let status = collaboration.status {
                pinImage = .circleTask(color: status.color, category: category)
            } else {
                pinImage = .circlePhoto(count: uploadsCount, category: category)
            }
            return PinDisplayOptions(
                pinImage: pinImage,
                alpha: anythingSelected ? 0.4 : 1,
                anchor: .center,
                offsetY: 0
            )
        }
    }

    /// pin display options provider for displaing pins in photo location selection mode (only show number of photos)
    static func addPhotoDisplayOptionsProvider(collaboration: Collaboration, selected: Bool,
                                               anythingSelected _: Bool) -> PinDisplayOptions
    {
        // optional category, also nil for the default (=unassigned)
        let category = (collaboration.category?.isDefault ?? true) ? nil : collaboration.category
        let archived = collaboration.isArchived
        let pinImage: PinImage
        if let status = collaboration.status {
            pinImage = archived ? .pinArchivedTask(category: category) :
                .pinTask(color: status.color, category: category)
        } else {
            let uploadsCount = collaboration.uploads.count
            pinImage = archived
                ? .pinArchivedPhoto(count: uploadsCount, category: category)
                : .pinPhoto(count: uploadsCount, category: category)
        }
        return PinDisplayOptions(
            pinImage: pinImage,
            alpha: selected ? 1.0 : 0.4,
            anchor: .bottom,
            offsetY: PinDisplayOptions.pinYOffset
        )
    }

    /// pin display options provider for displaing pins in new pin location selection mode (only show transparent circles)
    static func addPinDisplayOptionsProvider(collaboration: Collaboration, selected _: Bool,
                                             anythingSelected _: Bool) -> PinDisplayOptions
    {
        // optional category, also nil for the default (=unassigned)
        let category = (collaboration.category?.isDefault ?? true) ? nil : collaboration.category
        let uploadsCount = collaboration.uploads.count

        let pinImage: PinImage
        if collaboration.isArchived {
            // archived overrides any other rules
            if collaboration.status != nil {
                pinImage = .circleArchivedTask(category: category)
            } else {
                pinImage = .circleArchivedPhoto(count: uploadsCount, category: category)
            }
        } else if let status = collaboration.status, status.isCompleted {
            // completed status doesn't care about overdue or notes
            pinImage = .circleTask(color: status.color, category: category)
        } else if collaboration.isOverdue {
            pinImage = .circleOverdue
        } else if collaboration.hasUncompletedNotes {
            pinImage = .circleNote
        } else if let status = collaboration.status {
            pinImage = .circleTask(color: status.color, category: category)
        } else {
            pinImage = .circlePhoto(count: uploadsCount, category: category)
        }
        return PinDisplayOptions(
            pinImage: pinImage,
            alpha: 0.4,
            anchor: .center,
            offsetY: 0
        )
    }
}

/// Extension for converting between mapbox enums used for annotations anchoring
extension ViewAnnotationAnchor {
    // convert from ViewAnnotationAnchor (used by view annotations and by Range PinDisplayOptions) to IconAnchor
    func _asIconAnchor() -> IconAnchor {
        switch self {
        case .topLeft: return .topLeft
        case .top: return .top
        case .topRight: return .topRight
        case .left: return .left
        case .center: return .center
        case .right: return .right
        case .bottomLeft: return .bottomLeft
        case .bottom: return .bottom
        case .bottomRight: return .bottomRight
        @unknown default:
            fatalError("unknown ViewAnnotationAnchor")
        }
    }
}
