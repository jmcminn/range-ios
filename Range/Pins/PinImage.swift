import Foundation
import UIKit

/// Defines all possible canvas pins
enum PinImage {
    // TODO: 3941 pins
    case circlePhoto(count: Int, category: Category?)
    case circleArchivedPhoto(count: Int, category: Category?)
    case circleNote
    case circleOverdue
    case circleTask(color: UIColor, category: Category?)
    case circleArchivedTask(category: Category?)
    case pinPhoto(count: Int, category: Category?)
    case pinArchivedPhoto(count: Int, category: Category?)
    case pinPhotoWithNote(count: Int, category: Category?)
    case pinTask(color: UIColor, category: Category?)
    case pinTaskWithNote(color: UIColor, category: Category?)
    case pinTaskWithOverdue(color: UIColor, category: Category?)
    case pinArchivedTask(category: Category?)
    case copyPin

    private static var imageCache: [String: UIImage] = [:]

    // the unique id for each enum case, matches the image name for images
    // that are stored in the assets (all non task images)
    var id: String {
        switch self {
        case let .circlePhoto(count, category):
            return numberedImageWithCategoryName("marker", count, category)
        case let .circleArchivedPhoto(count, category):
            return numberedImageWithCategoryName("marker.archived", count, category)
        case .circleNote:
            return "marker.note"
        case .circleOverdue:
            return "marker.overdue"
        case let .circleTask(color, category):
            return coloredImageName("marker.task", color, category)
        case let .circleArchivedTask(category):
            return "marker.task.archived." + (category?.id ?? "")
        case let .pinPhoto(count, category):
            return numberedImageWithCategoryName("marker.selected", count, category)
        case let .pinArchivedPhoto(count, category):
            return numberedImageWithCategoryName("marker.selected.archived", count, category)
        case let .pinPhotoWithNote(count, category):
            return numberedImageWithCategoryName("marker.selected.badge", count, category)
        case let .pinTask(color, category):
            return coloredImageName("marker.selected.task", color, category)
        case let .pinTaskWithNote(color, category):
            return coloredImageName("marker.selected.task.note", color, category)
        case let .pinTaskWithOverdue(color, category):
            return coloredImageName("marker.selected.task.overdue", color, category)
        case let .pinArchivedTask(category):
            return "marker.selected.task.archived" + (category?.id ?? "")
        case .copyPin:
            return "marker.copyPin"
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
        case .circleNote, .circleOverdue:
            return getAndCacheImage(named: id)
        // constructed images
        case let .circlePhoto(count, category):
            return constructAndCacheImage(
                bgImage: "marker.background",
                bgColor: .Pink_03,
                overlay: "marker.overlay",
                icon: categoryImage(category) ?? numberedImage("marker", count, "icon")
            )
        case let .circleArchivedPhoto(count, category):
            return constructAndCacheImage(
                bgImage: "marker.background",
                bgColor: .Archived,
                overlay: "marker.overlay",
                icon: categoryImage(category) ?? numberedImage("marker", count, "icon")
            )
        case let .circleTask(color, category):
            return constructAndCacheImage(
                bgImage: "marker.background",
                bgColor: color,
                overlay: "marker.overlay",
                icon: categoryImage(category) ?? UIImage(named: "marker.task.icon")
            )
        case let .circleArchivedTask(category):
            return constructAndCacheImage(
                bgImage: "marker.background",
                bgColor: .Archived,
                overlay: "marker.overlay",
                icon: categoryImage(category) ?? UIImage(named: "marker.task.icon")
            )
        case let .pinPhoto(count, category):
            return constructAndCacheImage(
                bgImage: "marker.selected.background",
                bgColor: .Pink_03,
                overlay: "marker.selected.overlay",
                icon: categoryPinImage(category) ?? numberedImage("marker.selected", count, "icon")
            )
        case let .pinArchivedPhoto(count, category):
            return constructAndCacheImage(
                bgImage: "marker.selected.background",
                bgColor: .Archived,
                overlay: "marker.selected.overlay",
                icon: categoryPinImage(category) ?? numberedImage("marker.selected", count, "icon")
            )
        case let .pinPhotoWithNote(count, category):
            return constructAndCacheImage(
                bgImage: "marker.selected.background",
                bgColor: .Pink_03,
                overlay: "marker.selected.overlay",
                icon: categoryPinImage(category) ?? numberedImage("marker.selected", count, "icon"),
                badge: "marker.selected.overlay.note"
            )
        case let .pinTask(color, category):
            return constructAndCacheImage(
                bgImage: "marker.selected.background",
                bgColor: color,
                overlay: "marker.selected.overlay",
                icon: categoryPinImage(category) ?? UIImage(named: "marker.selected.task.icon")
            )
        case let .pinTaskWithNote(color, category):
            return constructAndCacheImage(
                bgImage: "marker.selected.background",
                bgColor: color,
                overlay: "marker.selected.overlay",
                icon: categoryPinImage(category) ?? UIImage(named: "marker.selected.task.icon"),
                badge: "marker.selected.overlay.note"
            )
        case let .pinTaskWithOverdue(color, category):
            return constructAndCacheImage(
                bgImage: "marker.selected.background",
                bgColor: color,
                overlay: "marker.selected.overlay",
                icon: categoryPinImage(category) ?? UIImage(named: "marker.selected.task.icon"),
                badge: "marker.selected.overlay.overdue"
            )
        case let .pinArchivedTask(category):
            return constructAndCacheImage(
                bgImage: "marker.selected.background",
                bgColor: .Archived,
                overlay: "marker.selected.overlay",
                icon: categoryPinImage(category) ?? UIImage(named: "marker.selected.task.icon")
            )
        case .copyPin:
            return getAndCacheImage(named: id)
        }
    }

    /// Loads the image from app assets and puts into `imageCache`
    private func getAndCacheImage(named imageName: String) -> UIImage? {
        guard let image = UIImage(named: imageName) else { return nil }
        PinImage.imageCache[imageName] = image
        return image
    }

    /// Combines background image (using given tint color) with a (foreground) overlay and with an image on top and puts into cache
    /// with this pin image id.
    /// It allows to construct pins that have different background color and same foreground
    /// If `badge` name is provided it adds one more layer, which is a badge for overdue or note
    private func constructAndCacheImage(
        bgImage: String,
        bgColor: UIColor,
        overlay: String,
        icon: String,
        badge: String? = nil
    ) -> UIImage? {
        let iconImage = UIImage(named: icon)
        return constructAndCacheImage(
            bgImage: bgImage,
            bgColor: bgColor,
            overlay: overlay,
            icon: iconImage,
            badge: badge
        )
    }

    private func constructAndCacheImage(
        bgImage: String,
        bgColor: UIColor,
        overlay: String,
        icon: UIImage?,
        badge: String? = nil
    ) -> UIImage? {
        guard var image = UIImage(named: bgImage)?
            .withTintColor(bgColor, renderingMode: .alwaysTemplate)
            .mergeWith(topImage: UIImage(named: overlay))
            .mergeWith(topImage: icon)
        else { return nil }
        if let badge = badge, let badgeImage = UIImage(named: badge) {
            image = image.mergeWith(topImage: badgeImage)
        }
        PinImage.imageCache[id] = image
        return image
    }

    // Create white image for category placed on the background of the size of the circle marker (so it's not stretched)
    private func categoryImage(_ category: Category?) -> UIImage? {
        category?.icon?
            .imageResized(toFill: 28)
            .addCircleBackground(bgSize: CGSize(width: 40, height: 40), bgColor: .clear, strokeColor: nil)
            .withTintColor(.white, renderingMode: .alwaysTemplate)
    }

    // Create white image for category placed on the background of the size of the pin marker
    // (so it's not stretched) and offset so it's placed in the pin circle area
    private func categoryPinImage(_ category: Category?) -> UIImage? {
        category?.icon?
            .imageResized(toFill: 28)
            .positionInImage(ofSize: CGSize(width: 56, height: 78), withCenterAt: CGPoint(x: 28, y: 32))
            .withTintColor(.white, renderingMode: .alwaysTemplate)
    }

    private func coloredImageName(_ prefix: String, _ color: UIColor, _ category: Category? = nil) -> String {
        let categorySuffix = if let category { ".\(category.id)" } else { "" }
        return "\(prefix).\(color.hexString)\(categorySuffix)"
    }

    private func numberedImageWithCategoryName(_ prefix: String, _ number: Int, _ category: Category? = nil) -> String {
        numberedImageName(prefix, number, category?.id)
    }

    private func numberedImage(_ prefix: String, _ number: Int, _ suffix: String? = nil) -> UIImage? {
        UIImage(named: numberedImageName(prefix, number, suffix))
    }
}
