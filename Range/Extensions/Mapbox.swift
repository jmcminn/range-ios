import Foundation
import MapboxMaps

/// Conform PointAnnotation to WithId, so it can be used in Realm.updateArray (see Realm extension)
extension PointAnnotation: WithId {}
