import Foundation
import UIKit

/// Defines all possible canvas pins
enum PinImage {
    case circlePhoto(count: Int)
    case circleNote
    case circleOverdue
    case circleTask(color: UIColor)
    case pinPhoto(count: Int)
    case pinPhotoWithNote(count: Int)
    case pinNote
    case pinTask(color: UIColor)
    case pinTaskWithNote(color: UIColor)
    case pinTaskWithOverdue(color: UIColor)

    private static var imageCache: [String: UIImage] = [:]

    // the unique id for each enum case, matches the image name for images
    // that are stored in the assets (all non task images)
    var id: String {
        switch self {
        case let .circlePhoto(count):
            return numberedImageName("marker.", count)
        case .circleNote:
            return "marker.note"
        case .circleOverdue:
            return "marker.overdue"
        case let .circleTask(color):
            return "marker.task." + color.toHexString()
        case let .pinPhoto(count):
            return numberedImageName("marker.selected.", count)
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
        case .circlePhoto, .circleNote, .circleOverdue, .pinPhoto, .pinPhotoWithNote, .pinNote:
            return PinImage.getAndCacheImage(named: id)

        // constructed images
        case let .circleTask(color):
            return PinImage.constructAndCacheImage(
                withId: id,
                backgroundImageName: "marker.task.background",
                backgroundTint: color,
                imageName: "marker.task.overlay"
            )

        case let .pinTask(color):
            return PinImage.constructAndCacheImage(
                withId: id,
                backgroundImageName: "task.selected.background",
                backgroundTint: color,
                imageName: "task.selected.overlay"
            )

        case let .pinTaskWithNote(color):
            return PinImage.constructAndCacheImage(
                withId: id,
                backgroundImageName: "task.selected.background",
                backgroundTint: color,
                imageName: "task.selected.note.overlay"
            )
        case let .pinTaskWithOverdue(color):
            return PinImage.constructAndCacheImage(
                withId: id,
                backgroundImageName: "task.selected.background",
                backgroundTint: color,
                imageName: "task.selected.overdue.overlay"
            )
        }
    }

    /// Loads the image from app assets and puts into `imageCache`
    private static func getAndCacheImage(named imageName: String) -> UIImage? {
        guard let image = UIImage(named: imageName) else { return nil }
        imageCache[imageName] = image
        return image
    }

    /// Combines background image (using given tint color) with a (foreground) image and puts into cache with given id.
    /// It allows to construct pins that have different background color and same foreground
    private static func constructAndCacheImage(withId id: String,
                                               backgroundImageName: String, backgroundTint: UIColor,
                                               imageName: String) -> UIImage?
    {
        guard let image = UIImage(named: backgroundImageName)?
            .withTintColor(backgroundTint, renderingMode: .alwaysTemplate)
            .mergeWith(topImage: UIImage(named: imageName)) else { return nil }
        imageCache[id] = image
        return image
    }
}
