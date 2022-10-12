import Foundation
import MapboxMaps
import OSLog

/// Conform PointAnnotation to WithId, so it can be used in Realm.updateArray (see Realm extension)
extension PointAnnotation: WithId {}

public extension Style {
    /// Wrapper for addImage function that loads the image by name and logs all the errors instead of throwing
    func addImage(named imageName: String) {
        guard image(withId: imageName) == nil else {
            // already added
            return
        }
        if let image = UIImage(named: imageName) {
            do {
                try addImage(image, id: imageName, stretchX: [], stretchY: [])
            } catch {
                Logger.mapbox.error("addImage to style failed: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            Logger.assets.error("Couldn't load the \(imageName) image from assets")
        }
    }
}
