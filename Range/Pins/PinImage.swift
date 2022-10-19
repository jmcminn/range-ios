import Foundation
import UIKit

/// Defines all possible canvas pins
enum PinImage {
    case circlePhoto(count: Int)
    case circleArchivedPhoto(count: Int)
    case circleNote
    case circleOverdue
    case circleTask(color: UIColor)
    case circleArchivedTask
    case pinPhoto(count: Int)
    case pinArchivedPhoto(count: Int)
    case pinPhotoWithNote(count: Int)
    case pinNote
    case pinTask(color: UIColor)
    case pinTaskWithNote(color: UIColor)
    case pinTaskWithOverdue(color: UIColor)
    case pinArchivedTask

    private static var imageCache: [String: UIImage] = [:]

    // the unique id for each enum case, matches the image name for images
    // that are stored in the assets (all non task images)
    var id: String {
        switch self {
        case let .circlePhoto(count):
            return numberedImageName("marker.", count)
        case let .circleArchivedPhoto(count):
            return numberedImageName("marker.archived.", count)
        case .circleNote:
            return "marker.note"
        case .circleOverdue:
            return "marker.overdue"
        case let .circleTask(color):
            return "marker.task." + color.toHexString()
        case .circleArchivedTask:
            return "marker.task.archived"
        case let .pinPhoto(count):
            return numberedImageName("marker.selected.", count)
        case let .pinArchivedPhoto(count):
            return numberedImageName("marker.selected.archived.", count)
        case let .pinPhotoWithNote(count):
            return numberedImageName("marker.selected.badge.", count)
        case .pinNote:
            return "marker.selected.note"
        case let .pinTask(color):
            return "marker.selected.task." + color.toHexString()
        case let .pinTaskWithNote(color):
            return "marker.selected.task.note." + color.toHexString()
        case let .pinTaskWithOverdue(color):
            return "marker.selected.task.overdue." + color.toHexString()
        case .pinArchivedTask:
            return "marker.selected.task.archived"
        }
    }

    // returns UIImage for this pin image.
    // task images are generated, other images are provided in the assets
    // they are all cached on first read
    var image: UIImage? {
        let id = id
        if let image = PinImage.imageCache[id] {
            return image
        }
        switch self {
        // images from resources
        case .circleNote, .circleOverdue, .pinNote:
            return getAndCacheImage(named: id)
        // constructed images
        case let .circlePhoto(count):
            return constructAndCacheImage(
                bgImage: "marker.background",
                bgColor: .Pink_03,
                image: numberedImageName("marker.overlay.", count)
            )
        case let .circleArchivedPhoto(count):
            return constructAndCacheImage(
                bgImage: "marker.background",
                bgColor: .Neutral_05,
                image: numberedImageName("marker.overlay.", count)
            )
        case let .circleTask(color):
            return constructAndCacheImage(
                bgImage: "marker.background",
                bgColor: color,
                image: "marker.task.overlay"
            )
        case .circleArchivedTask:
            return constructAndCacheImage(
                bgImage: "marker.background",
                bgColor: .Neutral_05,
                image: "marker.task.overlay"
            )
        case let .pinPhoto(count):
            return constructAndCacheImage(
                bgImage: "marker.selected.background",
                bgColor: .Pink_03,
                image: numberedImageName("marker.selected.overlay.", count)
            )
        case let .pinArchivedPhoto(count):
            return constructAndCacheImage(
                bgImage: "marker.selected.background",
                bgColor: .Neutral_05,
                image: numberedImageName("marker.selected.overlay.", count)
            )
        case let .pinPhotoWithNote(count):
            return constructAndCacheImage(
                bgImage: "marker.selected.background",
                bgColor: .Pink_03,
                image: numberedImageName("marker.selected.overlay.", count),
                badge: "marker.selected.overlay.note"
            )
        case let .pinTask(color):
            return constructAndCacheImage(
                bgImage: "marker.selected.background",
                bgColor: color,
                image: "task.selected.overlay"
            )
        case let .pinTaskWithNote(color):
            return constructAndCacheImage(
                bgImage: "marker.selected.background",
                bgColor: color,
                image: "task.selected.overlay",
                badge: "marker.selected.overlay.note"
            )
        case let .pinTaskWithOverdue(color):
            return constructAndCacheImage(
                bgImage: "marker.selected.background",
                bgColor: color,
                image: "task.selected.overlay",
                badge: "marker.selected.overlay.overdue"
            )
        case .pinArchivedTask:
            return constructAndCacheImage(
                bgImage: "marker.selected.background",
                bgColor: .Neutral_05,
                image: "task.selected.overlay"
            )
        }
    }

    /// Loads the image from app assets and puts into `imageCache`
    private func getAndCacheImage(named imageName: String) -> UIImage? {
        guard let image = UIImage(named: imageName) else { return nil }
        PinImage.imageCache[imageName] = image
        return image
    }

    /// Combines background image (using given tint color) with a (foreground) image and puts into cache with this pin image id.
    /// It allows to construct pins that have different background color and same foreground
    /// If `badge` name is provided it adds one more layer, which is a badge for overdue or note
    private func constructAndCacheImage(
        bgImage: String,
        bgColor: UIColor,
        image: String,
        badge: String? = nil
    ) -> UIImage? {
        guard var image = UIImage(named: bgImage)?
            .withTintColor(bgColor, renderingMode: .alwaysTemplate)
            .mergeWith(topImage: UIImage(named: image)) else { return nil }
        if let badge = badge, let badgeImage = UIImage(named: badge) {
            image = image.mergeWith(topImage: badgeImage)
        }
        PinImage.imageCache[id] = image
        return image
    }
}
