import CoreLocation
import Foundation
import MapboxMaps
import Turf
import UIKit

/// Pin information, can be instantiated from different objects and is used for managing the currently selected pin.
struct PinPoint {
    let id: String
    let point: Point

    init?(fromFeature: Turf.Feature?) {
        guard let feature = fromFeature else { return nil }
        guard case let .string(featureId) = feature.identifier else { return nil }
        guard case let .point(point) = feature.geometry?.geometry else { return nil }
        id = featureId
        self.point = point
    }

    init?(fromGeometry: Geometry?) {
        guard let geometry = fromGeometry else { return nil }
        guard case let .point(point) = geometry.geometry else { return nil }
        id = geometry.id
        self.point = point
    }

    init?(fromPointAnnotation: PointAnnotation?) {
        guard let pointAnnotation = fromPointAnnotation else { return nil }
        id = pointAnnotation.id
        point = pointAnnotation.point
    }

    init?(fromPinView: PinView?) {
        guard let pinView = fromPinView else { return nil }
        id = pinView.id
        point = pinView.point
    }
}
