import Foundation
import MapboxMaps

/// Stores image and layout options for the pin
/// This is a universal description, independent of the pin rendering - whether it's Mapbox annotations or view annotations - they
/// configure the pins using different set of flags (with same meaning, but not using same struct)
struct PinDisplayOptions {
    /// the image to display for the pin
    var imageName: String
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
    /// pin display options provider for regular display of pins
    static func regularPinDisplayOptionsProvider(collaboration: Collaboration, selected: Bool,
                                                 anythingSelected: Bool) -> PinDisplayOptions
    {
        let uploadsCount = collaboration.uploads.count
        let hasUncompletedNotes = collaboration.hasUncompletedNotes
        if selected {
            return PinDisplayOptions(
                // TODO: support request for upload update
                imageName: hasUncompletedNotes
                    ? (uploadsCount == 0
                        ? "marker.selected.note"
                        : numberedImageName("marker.selected.badge.", uploadsCount))
                    : numberedImageName("marker.selected.", uploadsCount),
                alpha: 1,
                anchor: .bottom,
                offsetY: -4
            )
        } else {
            return PinDisplayOptions(
                imageName: hasUncompletedNotes
                    ? "marker.note"
                    : numberedImageName("marker.", uploadsCount),
                alpha: anythingSelected ? 0.4 : 1,
                anchor: .center,
                offsetY: 0
            )
        }
    }

    /// pin display options provider for displaing pins in photo location selection mode (only show number of photos)
    static func addPhotoPinDisplayOptionsProvider(collaboration: Collaboration, selected: Bool,
                                                  anythingSelected _: Bool) -> PinDisplayOptions
    {
        PinDisplayOptions(
            imageName: numberedImageName("marker.selected.", collaboration.uploads.count),
            alpha: selected ? 1.0 : 0.4,
            anchor: .bottom,
            offsetY: -4
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
