import Foundation
import MapboxMaps
import OSLog

/// Conform PointAnnotation to WithId, so it can be used in Realm.updateArray (see Realm extension)
extension PointAnnotation: WithId {}

internal extension Style {
    /// Wrapper for addImage function that adds given pinImage and  logs all the errors instead of throwing
    func addPinImage(_ pinImage: PinImage) {
        let id = pinImage.id
        guard image(withId: id) == nil else {
            // already added
            return
        }
        guard let imageToAdd = pinImage.image else {
            Logger.assets.error("Image not provided for \(id)")
            return
        }
        do {
            try addImage(imageToAdd, id: id, stretchX: [], stretchY: [])
        } catch {
            Logger.mapbox.error("addImage to style failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
